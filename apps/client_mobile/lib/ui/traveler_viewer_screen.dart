import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';

class TravelerViewerController {
  final MobileDiContainer di;
  final Map<String, bool> localChecklistState = {};
  TripPackage? loadedTrip;

  TravelerViewerController({required this.di});

  /// Strictly read-only schedule viewer; only local checklist items can be toggled.
  Future<TripPackage> openTtFileStream(List<int> rawBytes, {String? pin}) async {
    final trip = await di.importTripUseCase.execute(containerBytes: rawBytes, userPin: pin);
    loadedTrip = trip;
    await di.tripRepository.saveTrip(trip);
    return trip;
  }

  void toggleLocalChecklistItem(String itemId, bool checked) {
    localChecklistState[itemId] = checked;
  }

  bool isChecklistItemChecked(String itemId, {bool defaultVal = false}) {
    return localChecklistState[itemId] ?? defaultVal;
  }

  Future<List<int>?> getAttachmentBlob(String sha256Checksum) {
    return di.attachmentStorage.readBlobBySha256(sha256Checksum);
  }
}
