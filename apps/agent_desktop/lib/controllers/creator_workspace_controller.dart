import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/hexagonal_di_container.dart';

class CreatorWorkspaceController {
  final HexagonalDiContainer di;
  TripPackage activeTrip;

  CreatorWorkspaceController({required this.di, required this.activeTrip});

  List<ScheduleValidationIssue> validateSchedule() =>
      di.manageTripScheduleUseCase.validate(activeTrip);

  void addEvent({
    required int dayNumber,
    required ItineraryEvent event,
  }) {
    activeTrip = di.manageTripScheduleUseCase.addEvent(
      trip: activeTrip,
      dayNumber: dayNumber,
      event: event,
    );
    di.tripRepository.saveTrip(activeTrip);
  }

  void updateEvent({
    required int dayNumber,
    required ItineraryEvent updatedEvent,
  }) {
    activeTrip = di.manageTripScheduleUseCase.updateEvent(
      trip: activeTrip,
      dayNumber: dayNumber,
      updatedEvent: updatedEvent,
    );
    di.tripRepository.saveTrip(activeTrip);
  }

  void removeEvent({
    required int dayNumber,
    required String eventId,
  }) {
    activeTrip = di.manageTripScheduleUseCase.removeEvent(
      trip: activeTrip,
      dayNumber: dayNumber,
      eventId: eventId,
    );
    di.tripRepository.saveTrip(activeTrip);
  }

  void reorderEvents({
    required int dayNumber,
    required int oldIndex,
    required int newIndex,
  }) {
    activeTrip = di.manageTripScheduleUseCase.reorderEvents(
      trip: activeTrip,
      dayNumber: dayNumber,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
    di.tripRepository.saveTrip(activeTrip);
  }

  void moveEventAcrossDays({
    required String eventId,
    required int fromDayNumber,
    required int toDayNumber,
    required String newStartIso8601,
    required String newEndIso8601,
  }) {
    activeTrip = di.manageTripScheduleUseCase.moveEventAcrossDays(
      trip: activeTrip,
      eventId: eventId,
      fromDayNumber: fromDayNumber,
      toDayNumber: toDayNumber,
      newStartIso8601: newStartIso8601,
      newEndIso8601: newEndIso8601,
    );
    di.tripRepository.saveTrip(activeTrip);
  }

  Future<TripPackage> attachFileToEvent({
    required int dayNumber,
    required String eventId,
    required String filename,
    required String mimeType,
    required AttachmentCategory category,
    required List<int> rawBytes,
  }) async {
    activeTrip = await di.attachMediaUseCase.execute(
      trip: activeTrip,
      dayNumber: dayNumber,
      eventId: eventId,
      input: RawAttachmentInput(
        filename: filename,
        mimeType: mimeType,
        category: category,
        rawBytes: rawBytes,
      ),
    );
    await di.tripRepository.saveTrip(activeTrip);
    return activeTrip;
  }

  Future<List<int>> exportToTtContainer({
    String? pin,
    bool isTemplate = false,
  }) async {
    return di.exportTripUseCase.execute(
      trip: activeTrip,
      userPin: pin,
      exportAsTemplate: isTemplate,
    );
  }
}
