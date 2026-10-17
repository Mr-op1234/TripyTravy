import '../../adapters/serialization/protobuf_trip_mapper.dart';
import '../entities/attachment_descriptor.dart';
import '../entities/trip_package.dart';
import '../policies/template_sanitizer_policy.dart';
import '../ports/outbound_ports.dart';

class AttachMediaOrVoucherUseCase {
  final AttachmentProcessorPort processor;
  final AttachmentStoragePort storage;
  const AttachMediaOrVoucherUseCase({required this.processor, required this.storage});

  Future<TripPackage> execute({
    required TripPackage trip,
    required int dayNumber,
    required String eventId,
    required RawAttachmentInput input,
  }) async {
    if (!processor.canHandle(input.mimeType, input.category)) {
      throw ArgumentError('Unsupported attachment format: ${input.mimeType} for category: ${input.category}');
    }
    final processed = await processor.process(input);
    final desc = await storage.storeDeduplicated(processed);
    final assets = List<AttachmentDescriptor>.from(trip.allAssets);
    if (!assets.any((a) => a.assetId == desc.assetId)) assets.add(desc);

    return trip.copyWith(
      allAssets: assets,
      days: trip.days.map((d) {
        if (d.dayNumber != dayNumber) return d;
        return d.copyWith(
          events: d.events.map((e) {
            if (e.eventId != eventId) return e;
            final updatedIds = {...e.attachmentAssetIds, desc.assetId}.toList();
            return e.copyWith(attachmentAssetIds: updatedIds);
          }).toList(),
        );
      }).toList(),
    );
  }
}

class ExportTripContainerUseCase {
  final AttachmentStoragePort storage;
  final ContainerCipherPort cipher;
  final TemplateSanitizerPolicy sanitizer;
  final ProtobufTripMapper mapper;

  const ExportTripContainerUseCase({
    required this.storage,
    required this.cipher,
    this.sanitizer = const TemplateSanitizerPolicy(),
    this.mapper = const ProtobufTripMapper(),
  });

  Future<List<int>> execute({
    required TripPackage trip,
    String? userPin,
    bool exportAsTemplate = false,
  }) async {
    final sanitizedTrip = exportAsTemplate ? sanitizer.sanitizeForTemplate(trip) : trip;

    final indexed = <AttachmentDescriptor>[];
    final blobs = <int>[];
    final offsets = <String, int>{};

    for (final a in sanitizedTrip.allAssets) {
      final existingOffset = offsets[a.sha256Checksum];
      if (existingOffset != null) {
        indexed.add(a.copyWith(byteOffset: existingOffset));
        continue;
      }
      final blobBytes = await storage.readBlobBySha256(a.sha256Checksum);
      if (blobBytes == null) {
        throw StateError('Missing asset blob in storage for checksum: ${a.sha256Checksum}');
      }
      final offset = blobs.length;
      offsets[a.sha256Checksum] = offset;
      indexed.add(a.copyWith(byteOffset: offset, byteSize: blobBytes.length));
      blobs.addAll(blobBytes);
    }

    final finalTrip = sanitizedTrip.copyWith(allAssets: indexed);
    final wireBytes = mapper.toWireBytes(finalTrip);

    return cipher.packContainer(
      protobufBytes: wireBytes,
      concatenatedAssets: blobs,
      userPin: userPin,
      hasEmbeddedMapSlice: finalTrip.offlineMapSlice != null,
      isTemplateSanitized: finalTrip.isTemplate,
    );
  }
}

class ImportTripContainerUseCase {
  final AttachmentStoragePort storage;
  final ContainerCipherPort cipher;
  final ProtobufTripMapper mapper;

  const ImportTripContainerUseCase({
    required this.storage,
    required this.cipher,
    this.mapper = const ProtobufTripMapper(),
  });

  Future<TripPackage> execute({
    required List<int> containerBytes,
    String? userPin,
  }) async {
    final unpacked = await cipher.unpackContainer(
      containerBytes: containerBytes,
      userPin: userPin,
    );

    final trip = mapper.fromWireBytes(unpacked.protobufBytes);

    for (final asset in trip.allAssets) {
      if (asset.byteOffset + asset.byteSize <= unpacked.concatenatedAssets.length) {
        final blob = unpacked.concatenatedAssets.sublist(
          asset.byteOffset,
          asset.byteOffset + asset.byteSize,
        );
        await storage.putRawBlob(asset.sha256Checksum, blob);
      }
    }

    return trip;
  }
}
