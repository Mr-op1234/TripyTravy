import '../entities/attachment_descriptor.dart';
import '../entities/itinerary_event.dart';
import '../entities/trip_package.dart';
import '../policies/schedule_conflict_policy.dart';
import '../policies/template_sanitizer_policy.dart';
import '../ports/outbound_ports.dart';

abstract class ManageTripScheduleUseCasePort {
  TripPackage createTrip({
    required String tripId,
    required String title,
    String subtitle,
    List<String> destinationTags,
    required String startDateIso8601,
    required String endDateIso8601,
    required String primaryTimezoneIana,
    String currencyCodeIso4217,
    String languageBcp47,
    List<TravelerProfile> travelers,
  });

  TripPackage addEvent({
    required TripPackage trip,
    required int dayNumber,
    required ItineraryEvent event,
  });

  TripPackage updateEvent({
    required TripPackage trip,
    required int dayNumber,
    required ItineraryEvent updatedEvent,
  });

  TripPackage removeEvent({
    required TripPackage trip,
    required int dayNumber,
    required String eventId,
  });

  TripPackage reorderEvents({
    required TripPackage trip,
    required int dayNumber,
    required int oldIndex,
    required int newIndex,
  });

  TripPackage moveEventAcrossDays({
    required TripPackage trip,
    required int fromDayNumber,
    required int toDayNumber,
    required String eventId,
    required String newStartIso8601,
    required String newEndIso8601,
  });

  List<ScheduleValidationIssue> validate(TripPackage trip);
}

abstract class AttachMediaOrVoucherUseCasePort {
  Future<TripPackage> execute({
    required TripPackage trip,
    required int dayNumber,
    required String eventId,
    required RawAttachmentInput input,
  });
}

abstract class ExportTripContainerUseCasePort {
  Future<List<int>> execute({
    required TripPackage trip,
    String? userPin,
    bool exportAsTemplate,
  });
}

abstract class ImportTripContainerUseCasePort {
  Future<TripPackage> execute({
    required List<int> containerBytes,
    String? userPin,
  });
}
