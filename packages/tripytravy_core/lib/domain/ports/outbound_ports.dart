import '../entities/attachment_descriptor.dart';
import '../entities/itinerary_event.dart';
import '../entities/traveler_checklist.dart';
import '../entities/trip_package.dart';
import '../value_objects/geo_coordinate.dart';

class RawAttachmentInput {
  final String filename, mimeType;
  final AttachmentCategory category;
  final List<int> rawBytes;
  const RawAttachmentInput({
    required this.filename,
    required this.mimeType,
    required this.category,
    required this.rawBytes,
  });
}

class ProcessedAttachment {
  final String filename, mimeType;
  final AttachmentCategory category;
  final AttachmentVisibility visibility;
  final List<int> processedBytes;
  final Map<String, Object?> metadata;
  const ProcessedAttachment({
    required this.filename,
    required this.mimeType,
    required this.category,
    required this.visibility,
    required this.processedBytes,
    this.metadata = const {},
  });
}

abstract class AttachmentProcessorPort {
  bool canHandle(String mimeType, AttachmentCategory category);
  Future<ProcessedAttachment> process(RawAttachmentInput input);
}

abstract class AttachmentStoragePort {
  Future<AttachmentDescriptor> storeDeduplicated(ProcessedAttachment attachment);
  Future<List<int>?> readBlobBySha256(String sha256Checksum);
  Future<void> putRawBlob(String sha256Checksum, List<int> bytes);
  Future<bool> hasBlob(String sha256Checksum);
  Future<String?> getBlobPath(String sha256Checksum);
  int get uniqueBlobCount;
}

class UnpackedTtrvPayload {
  final List<int> protobufBytes, concatenatedAssets;
  final bool isPinProtected, hasEmbeddedMapSlice, isTemplateSanitized;
  const UnpackedTtrvPayload({
    required this.protobufBytes,
    required this.concatenatedAssets,
    required this.isPinProtected,
    required this.hasEmbeddedMapSlice,
    required this.isTemplateSanitized,
  });
}

abstract class ContainerCipherPort {
  Future<List<int>> packContainer({
    required List<int> protobufBytes,
    required List<int> concatenatedAssets,
    String? userPin,
    bool hasEmbeddedMapSlice = false,
    bool isTemplateSanitized = false,
  });
  Future<UnpackedTtrvPayload> unpackContainer({
    required List<int> containerBytes,
    String? userPin,
  });
}

abstract class TripRepositoryPort {
  Future<void> saveTrip(TripPackage trip);
  Future<TripPackage?> getTripById(String tripId);
  Future<List<TripPackage>> listAllTrips();
  Future<bool> deleteTrip(String tripId);
  Future<String?> getActiveTripId();
  Future<void> setActiveTripId(String tripId);
}

abstract class ChecklistRepositoryPort {
  Future<TripChecklistState> getChecklistForTrip(String tripId);
  Future<void> saveChecklist(TripChecklistState checklist);
  Future<bool> deleteChecklist(String tripId);
}

abstract class RouteProviderPort {
  Future<RoutePath> computeRoute({
    required String routeId,
    required String fromEventId,
    required String toEventId,
    required GeoCoordinate origin,
    required GeoCoordinate destination,
    required TransitMode mode,
  });
}
