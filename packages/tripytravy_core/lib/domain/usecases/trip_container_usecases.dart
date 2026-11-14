import 'dart:convert';
import '../entities/itinerary_event.dart';
import 'package:crypto/crypto.dart';
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
    final assets = <String, AttachmentDescriptor>{for (final asset in trip.allAssets) asset.sha256Checksum: asset};
    Future<TripDocumentRecord> indexDocument(TripDocumentRecord doc) async {
      if (doc.base64Data == null || doc.base64Data!.isEmpty) return doc;
      final bytes = base64Decode(doc.base64Data!.split(',').last.replaceAll(RegExp(r'\s+'), ''));
      final hash = sha256.convert(bytes).toString();
      await storage.putRawBlob(hash, bytes);
      assets.putIfAbsent(hash, () => AttachmentDescriptor(assetId: 'document_$hash', filename: doc.fileName, mimeType: 'application/octet-stream', category: AttachmentCategory.hotelVoucher, visibility: AttachmentVisibility.privateBooking, byteSize: bytes.length, sha256Checksum: hash));
      return doc.copyWith(assetSha256: hash, filePath: '', clearEmbeddedData: true);
    }
    final documents = <TripDocumentRecord>[];
    for (final doc in trip.documents) { documents.add(await indexDocument(doc)); }
    final days = <ItineraryDay>[];
    for (final day in trip.days) {
      final events = <ItineraryEvent>[];
      for (final event in day.events) {
        final refs = <TripDocumentRecord>[];
        final seen = <String>{};
        for (final doc in event.documents) {
          final ref = await indexDocument(doc);
          if (seen.add(ref.assetSha256 ?? ref.id)) refs.add(ref);
        }
        final photos = <String>[];
        for (final photo in event.photos) {
          var ref = photo;
          if (photo.startsWith('data:image/')) {
            final bytes = base64Decode(photo.split(',').last);
            final hash = sha256.convert(bytes).toString();
            await storage.putRawBlob(hash, bytes);
            assets.putIfAbsent(hash, () => AttachmentDescriptor(assetId: 'photo_$hash', filename: 'photo', mimeType: photo.substring(5, photo.indexOf(';')), category: AttachmentCategory.photoGallery, visibility: AttachmentVisibility.templateSafe, byteSize: bytes.length, sha256Checksum: hash));
            ref = 'asset:$hash';
          }
          if (!photos.contains(ref)) photos.add(ref);
        }
        events.add(event.copyWith(documents: refs, photos: photos));
      }
      days.add(day.copyWith(events: events));
    }
    final indexedTrip = trip.copyWith(documents: documents, days: days, allAssets: assets.values.toList());
    final sanitizedTrip = exportAsTemplate ? sanitizer.sanitizeForTemplate(indexedTrip) : indexedTrip;

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
      final end = asset.byteOffset + asset.byteSize;
      if (asset.byteOffset < 0 ||
          asset.byteSize < 0 ||
          end < asset.byteOffset ||
          end > unpacked.concatenatedAssets.length) {
        throw FormatException('Invalid attachment bounds: ${asset.filename}');
      }
      final blob = unpacked.concatenatedAssets.sublist(asset.byteOffset, end);
      final verifyChecksum = trip.revision > 0 ||
          asset.assetId.startsWith('document_') ||
          asset.assetId.startsWith('photo_');
      if (verifyChecksum && sha256.convert(blob).toString() != asset.sha256Checksum) {
        throw FormatException('Attachment checksum mismatch: ${asset.filename}');
      }
      await storage.putRawBlob(asset.sha256Checksum, blob);
    }

    return trip;
  }
}
