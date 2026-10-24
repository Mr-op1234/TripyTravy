import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';

/// Primary controller for the Traveler viewer application.
/// Manages loaded trip itinerary, timeline calculations, persistent checklist, and media resolution.
class TravelerViewerController {
  final MobileDiContainer di;
  TripPackage? loadedTrip;
  TripChecklistState? _currentChecklist;
  TravelerTimelineService? _timelineService;

  TravelerViewerController({required this.di});

  TravelerTimelineService? get timeline => _timelineService;
  TripChecklistState? get checklist => _currentChecklist;

  /// Loads the active trip from local persistence.
  Future<TripPackage?> loadActiveTrip() async {
    final trip = await di.tripManager.getActiveTrip();
    if (trip != null) {
      loadedTrip = trip;
      _timelineService = TravelerTimelineService(trip: trip);
      _currentChecklist = await di.checklistRepository.getChecklistForTrip(trip.tripId);
    }
    return trip;
  }

  /// Strictly offline-first schedule viewer; imports a .ttrv container file and sets active.
  Future<TripPackage> openTtFileStream(List<int> rawBytes, {String? pin}) async {
    final trip = await di.tripManager.importTripFromContainer(rawBytes, userPin: pin);
    loadedTrip = trip;
    _timelineService = TravelerTimelineService(trip: trip);
    _currentChecklist = await di.checklistRepository.getChecklistForTrip(trip.tripId);
    return trip;
  }

  /// Toggles checklist item and persists immediately to disk.
  Future<TripChecklistState> toggleLocalChecklistItem(String itemId, bool checked) async {
    if (loadedTrip == null) {
      throw StateError('Cannot toggle checklist without an active trip loaded');
    }
    final updated = await di.tripManager.toggleChecklistItem(loadedTrip!.tripId, itemId, checked);
    _currentChecklist = updated;
    return updated;
  }

  /// Adds a custom item to the traveler's checklist.
  Future<TripChecklistState> addCustomChecklistItem(String title, {ChecklistCategory category = ChecklistCategory.misc}) async {
    if (loadedTrip == null) {
      throw StateError('Cannot add checklist item without an active trip loaded');
    }
    final item = TravelerChecklistItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      isCustom: true,
      isChecked: false,
    );
    final updated = await di.tripManager.addChecklistItem(loadedTrip!.tripId, item);
    _currentChecklist = updated;
    return updated;
  }

  /// Checks if a checklist item is checked.
  bool isChecklistItemChecked(String itemId, {bool defaultVal = false}) {
    if (_currentChecklist == null) return defaultVal;
    final item = _currentChecklist!.items.firstWhere(
      (i) => i.id == itemId,
      orElse: () => TravelerChecklistItem(id: itemId, title: '', isChecked: defaultVal),
    );
    return item.isChecked;
  }

  /// Resolves raw attachment bytes by SHA-256 hash.
  Future<List<int>?> getAttachmentBlob(String sha256Checksum) {
    return di.attachmentStorage.readBlobBySha256(sha256Checksum);
  }

  /// Resolves attachment local filesystem path for direct image/PDF rendering.
  Future<String?> getAttachmentFilePath(String sha256Checksum) {
    return di.attachmentStorage.getBlobPath(sha256Checksum);
  }
}
