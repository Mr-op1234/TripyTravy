import 'dart:convert';
import 'dart:io';
import '../../adapters/outbound/crypto/ttrv_container_cipher_adapter.dart';
import '../../adapters/outbound/persistence/file_cas_attachment_storage_adapter.dart';
import '../../adapters/outbound/persistence/file_checklist_repository_adapter.dart';
import '../../adapters/outbound/persistence/file_trip_repository_adapter.dart';
import '../entities/attachment_descriptor.dart';
import '../entities/traveler_checklist.dart';
import '../entities/trip_package.dart';
import '../ports/outbound_ports.dart';
import 'traveler_timeline_service.dart';
import 'trip_container_usecases.dart';

/// Fundamental application manager orchestrating offline-first trip lifecycle,
/// persistence, container synchronization, and traveler checklists.
class MobileTripManagerService {
  final TripRepositoryPort tripRepository;
  final AttachmentStoragePort attachmentStorage;
  final ChecklistRepositoryPort checklistRepository;
  final ContainerCipherPort cipher;
  final ImportTripContainerUseCase importTripUseCase;
  final ExportTripContainerUseCase exportTripUseCase;

  MobileTripManagerService({
    required this.tripRepository,
    required this.attachmentStorage,
    required this.checklistRepository,
    this.cipher = const TtrvContainerCipherAdapter(),
  })  : importTripUseCase = ImportTripContainerUseCase(
          storage: attachmentStorage,
          cipher: cipher,
        ),
        exportTripUseCase = ExportTripContainerUseCase(
          storage: attachmentStorage,
          cipher: cipher,
        );

  /// Convenient factory wiring persistent file-based adapters to a designated local app directory.
  factory MobileTripManagerService.fromDirectory(
    Directory baseDir, {
    ContainerCipherPort cipher = const TtrvContainerCipherAdapter(),
  }) {
    final tripRepo = FileTripRepositoryAdapter(baseDirectory: baseDir);
    final storage = FileCasAttachmentStorageAdapter(
      storageDirectory: Directory('${baseDir.path}/blobs'),
    );
    final checklistRepo =
        FileChecklistRepositoryAdapter(baseDirectory: baseDir);

    return MobileTripManagerService(
      tripRepository: tripRepo,
      attachmentStorage: storage,
      checklistRepository: checklistRepo,
      cipher: cipher,
    );
  }

  // --- Trip Management ---

  /// Imports a .ttrv container file from raw bytes, stores assets, saves to repository, and sets as active.
  Future<TripPackage> importTripFromContainer(
    List<int> containerBytes, {
    String? userPin,
  }) async {
    final trip = await importTripUseCase.execute(
      containerBytes: containerBytes,
      userPin: userPin,
    );
    await tripRepository.saveTrip(trip);
    await tripRepository.setActiveTripId(trip.tripId);
    return trip;
  }

  /// Imports a .ttrv container file from a file path.
  Future<TripPackage> importTripFromFile(
    File file, {
    String? userPin,
  }) async {
    final bytes = await file.readAsBytes();
    return importTripFromContainer(bytes, userPin: userPin);
  }

  /// Imports a trip directly from JSON map/payload.
  Future<TripPackage> importTripFromJson(Map<String, dynamic> json) async {
    final trip = TripPackage.fromJson(json);
    await tripRepository.saveTrip(trip);
    await tripRepository.setActiveTripId(trip.tripId);
    return trip;
  }

  /// Exports a trip package and all associated offline assets to a standalone .ttrv container.
  Future<List<int>> exportTripToContainer(
    String tripId, {
    String? userPin,
    bool exportAsTemplate = false,
  }) async {
    final trip = await tripRepository.getTripById(tripId);
    if (trip == null) {
      throw ArgumentError('Trip not found with id: $tripId');
    }
    return exportTripUseCase.execute(
      trip: trip,
      userPin: userPin,
      exportAsTemplate: exportAsTemplate,
    );
  }

  /// Lists all saved trips sorted chronologically.
  Future<List<TripPackage>> listAllTrips() => tripRepository.listAllTrips();

  /// Gets the currently active trip.
  Future<TripPackage?> getActiveTrip() async {
    final id = await tripRepository.getActiveTripId();
    if (id != null) {
      final trip = await tripRepository.getTripById(id);
      if (trip != null) return trip;
    }
    final all = await listAllTrips();
    return all.isNotEmpty ? all.first : null;
  }

  /// Sets a trip as the active itinerary.
  Future<void> setActiveTrip(String tripId) =>
      tripRepository.setActiveTripId(tripId);

  /// Deletes a trip and its checklist.
  Future<bool> deleteTrip(String tripId) async {
    await checklistRepository.deleteChecklist(tripId);
    return tripRepository.deleteTrip(tripId);
  }

  // --- Timeline & Navigation ---

  /// Returns the timeline navigation service for a trip.
  Future<TravelerTimelineService?> getTimelineService(String tripId) async {
    final trip = await tripRepository.getTripById(tripId);
    if (trip == null) return null;
    return TravelerTimelineService(trip: trip);
  }

  // --- Checklist Management ---

  /// Loads the checklist state for a trip (persisted on disk).
  Future<TripChecklistState> getChecklist(String tripId) =>
      checklistRepository.getChecklistForTrip(tripId);

  /// Toggles the check state of a checklist item.
  Future<TripChecklistState> toggleChecklistItem(
    String tripId,
    String itemId,
    bool isChecked,
  ) async {
    final state = await getChecklist(tripId);
    final updated = state.toggleItem(itemId, isChecked);
    await checklistRepository.saveChecklist(updated);
    return updated;
  }

  /// Adds a custom item to the trip checklist.
  Future<TripChecklistState> addChecklistItem(
    String tripId,
    TravelerChecklistItem item,
  ) async {
    final state = await getChecklist(tripId);
    final updated = state.addItem(item);
    await checklistRepository.saveChecklist(updated);
    return updated;
  }

  /// Removes an item from the trip checklist.
  Future<TripChecklistState> removeChecklistItem(
    String tripId,
    String itemId,
  ) async {
    final state = await getChecklist(tripId);
    final updated = state.removeItem(itemId);
    await checklistRepository.saveChecklist(updated);
    return updated;
  }

  /// Resets all items in a checklist to unchecked.
  Future<TripChecklistState> resetChecklist(String tripId) async {
    final state = await getChecklist(tripId);
    final updated = state.resetAll();
    await checklistRepository.saveChecklist(updated);
    return updated;
  }

  // --- Offline Assets & Media ---

  /// Resolves an asset's local file path for direct offline display.
  Future<String?> getAttachmentFilePath(String sha256Checksum) =>
      attachmentStorage.getBlobPath(sha256Checksum);

  /// Reads raw bytes for an asset.
  Future<List<int>?> getAttachmentBytes(String sha256Checksum) =>
      attachmentStorage.readBlobBySha256(sha256Checksum);
}
