import 'package:tripytravy_core/tripytravy_core.dart';
import 'di/mobile_di_container.dart';
import 'ui/traveler_viewer_screen.dart';

void main() async {
  final di = MobileDiContainer();
  final controller = TravelerViewerController(di: di);

  controller.toggleLocalChecklistItem('passport', true);
  controller.toggleLocalChecklistItem('charger', true);
  print('Mobile Traveler checklist state: ${controller.localChecklistState}');
}
