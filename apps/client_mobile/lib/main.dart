import 'package:tripytravy_core/tripytravy_core.dart';
import 'di/mobile_di_container.dart';
import 'ui/traveler_viewer_screen.dart';

void main() async {
  final di = MobileDiContainer();
  final controller = TravelerViewerController(di: di);

  const sampleTrip = TripPackage(
    tripId: 'trip_demo_1',
    title: 'Demo Trip',
    startDateIso8601: '2026-12-01',
    endDateIso8601: '2026-12-10',
    primaryTimezoneIana: 'UTC',
  );
  await di.tripRepository.saveTrip(sampleTrip);
  await controller.loadActiveTrip();

  await controller.toggleLocalChecklistItem('chk_passport', true);
  await controller.toggleLocalChecklistItem('chk_phone_charger', true);
  print(
      'Mobile Traveler checklist progress: ${(controller.checklist?.progressPercentage ?? 0) * 100}%');
}
