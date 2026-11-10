import '../entities/itinerary_event.dart';
import '../entities/trip_package.dart';
import '../policies/schedule_conflict_policy.dart';

class ManageTripScheduleUseCase {
  final ScheduleConflictPolicy schedulePolicy;

  const ManageTripScheduleUseCase({
    this.schedulePolicy = const ScheduleConflictPolicy(),
  });

  TripPackage createTrip({
    required String tripId,
    required String title,
    String subtitle = '',
    List<String> destinationTags = const [],
    required String startDateIso8601,
    required String endDateIso8601,
    required String primaryTimezoneIana,
    String currencyCodeIso4217 = 'USD',
    String languageBcp47 = 'en-US',
    List<TravelerProfile> travelers = const [],
  }) {
    final start = DateTime.parse(startDateIso8601);
    final end = DateTime.parse(endDateIso8601);
    final totalDays = end.difference(start).inDays + 1;

    final days = List.generate(totalDays > 0 ? totalDays : 1, (i) {
      final date = start.add(Duration(days: i)).toIso8601String().split('T')[0];
      return ItineraryDay(
        dayNumber: i + 1,
        dateIso8601: date,
        title: 'Day ${i + 1}',
        primaryTimezoneIana: primaryTimezoneIana,
      );
    });

    final trip = TripPackage(
      tripId: tripId,
      title: title,
      subtitle: subtitle,
      destinationTags: destinationTags,
      startDateIso8601: startDateIso8601,
      endDateIso8601: endDateIso8601,
      primaryTimezoneIana: primaryTimezoneIana,
      currencyCodeIso4217: currencyCodeIso4217,
      languageBcp47: languageBcp47,
      travelers: travelers,
      days: days,
    );

    return trip;
  }

  TripPackage addEvent({
    required TripPackage trip,
    required int dayNumber,
    required ItineraryEvent event,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final updatedEvents = [...day.events, event];
      _sortEventsChronologically(updatedEvents);
      return day.copyWith(events: updatedEvents);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage updateEvent({
    required TripPackage trip,
    required int dayNumber,
    required ItineraryEvent updatedEvent,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final updatedEvents = day.events
          .map((e) => e.eventId == updatedEvent.eventId ? updatedEvent : e)
          .toList();
      _sortEventsChronologically(updatedEvents);
      return day.copyWith(events: updatedEvents);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage removeEvent({
    required TripPackage trip,
    required int dayNumber,
    required String eventId,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final updatedEvents = day.events.where((e) => e.eventId != eventId).toList();
      return day.copyWith(
        events: updatedEvents,
        routes: day.routes
            .where((r) => r.fromEventId != eventId && r.toEventId != eventId)
            .toList(),
      );
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage reorderEvents({
    required TripPackage trip,
    required int dayNumber,
    required int oldIndex,
    required int newIndex,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final events = List<ItineraryEvent>.from(day.events);
      if (oldIndex < 0 || oldIndex >= events.length || newIndex < 0 || newIndex >= events.length) {
        return day;
      }
      final item = events.removeAt(oldIndex);
      events.insert(newIndex, item);
      return day.copyWith(events: events);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage moveEventAcrossDays({
    required TripPackage trip,
    required int fromDayNumber,
    required int toDayNumber,
    required String eventId,
    required String newStartIso8601,
    required String newEndIso8601,
  }) {
    ItineraryEvent? eventToMove;
    for (final day in trip.days) {
      if (day.dayNumber == fromDayNumber) {
        for (final e in day.events) {
          if (e.eventId == eventId) {
            eventToMove = e;
            break;
          }
        }
      }
    }

    if (eventToMove == null) return trip;

    final updatedEvent = eventToMove.copyWith(
      startIso8601: newStartIso8601,
      endIso8601: newEndIso8601,
    );

    final withoutOld = removeEvent(
      trip: trip,
      dayNumber: fromDayNumber,
      eventId: eventId,
    );

    return addEvent(
      trip: withoutOld,
      dayNumber: toDayNumber,
      event: updatedEvent,
    );
  }

  TripPackage addRoute({
    required TripPackage trip,
    required int dayNumber,
    required RoutePath route,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final routes = List<RoutePath>.from(day.routes);
      routes.removeWhere((r) => r.routeId == route.routeId);
      routes.add(route);
      return day.copyWith(routes: routes);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage addGeofence({
    required TripPackage trip,
    required int dayNumber,
    required GeofenceArea geofence,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final fences = List<GeofenceArea>.from(day.geofences);
      fences.removeWhere((g) => g.areaId == geofence.areaId);
      fences.add(geofence);
      return day.copyWith(geofences: fences);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  TripPackage addAttractionPoi({
    required TripPackage trip,
    required int dayNumber,
    required AttractionPoi poi,
  }) {
    final updatedDays = trip.days.map((day) {
      if (day.dayNumber != dayNumber) return day;
      final pois = List<AttractionPoi>.from(day.attractions);
      pois.removeWhere((p) => p.poiId == poi.poiId);
      pois.add(poi);
      return day.copyWith(attractions: pois);
    }).toList();

    return trip.copyWith(days: updatedDays);
  }

  List<ScheduleValidationIssue> validate(TripPackage trip) {
    return schedulePolicy.validateTrip(trip);
  }

  static void _sortEventsChronologically(List<ItineraryEvent> events) {
    events.sort((a, b) {
      final aDate = DateTime.tryParse(a.startIso8601) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(b.startIso8601) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
  }
}
