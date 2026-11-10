import '../entities/itinerary_event.dart';
import '../entities/trip_package.dart';

enum TimelineEventStatus {
  past,
  ongoing,
  upcoming,
}

class TimelineEvent {
  final int dayNumber;
  final String dayTitle;
  final String dayDateIso8601;
  final ItineraryEvent event;
  final DateTime? estimatedStartUtc;
  final DateTime? estimatedEndUtc;

  const TimelineEvent({
    required this.dayNumber,
    required this.dayTitle,
    required this.dayDateIso8601,
    required this.event,
    this.estimatedStartUtc,
    this.estimatedEndUtc,
  });

  bool get isFlight => event.eventType == EventType.flight;
  bool get isLodging => event.eventType == EventType.lodging;
  bool get isTransport => event.eventType == EventType.transport;
  bool get isActivity => event.eventType == EventType.activity;
  bool get isMeal => event.eventType == EventType.meal;
  bool get isNote => event.eventType == EventType.note;

  TimelineEventStatus getStatus(DateTime nowUtc) {
    if (estimatedStartUtc == null) return TimelineEventStatus.upcoming;
    if (estimatedEndUtc != null) {
      if (nowUtc.isAfter(estimatedEndUtc!)) return TimelineEventStatus.past;
      if (nowUtc.isAfter(estimatedStartUtc!) && nowUtc.isBefore(estimatedEndUtc!)) {
        return TimelineEventStatus.ongoing;
      }
    } else {
      if (nowUtc.isAfter(estimatedStartUtc!.add(const Duration(hours: 2)))) {
        return TimelineEventStatus.past;
      }
      if (nowUtc.isAfter(estimatedStartUtc!) &&
          nowUtc.isBefore(estimatedStartUtc!.add(const Duration(hours: 2)))) {
        return TimelineEventStatus.ongoing;
      }
    }
    return TimelineEventStatus.upcoming;
  }
}

/// Service calculating real-time traveler timeline information, navigation, and countdowns.
class TravelerTimelineService {
  final TripPackage trip;

  TravelerTimelineService({required this.trip});

  /// Flatten all events across days into a chronological sequence.
  List<TimelineEvent> getAllEventsChronological() {
    final List<TimelineEvent> items = [];
    for (final day in trip.days) {
      DateTime? dayDate;
      if (day.dateIso8601.isNotEmpty) {
        dayDate = DateTime.tryParse(day.dateIso8601)?.toUtc();
      }

      for (final ev in day.events) {
        DateTime? startUtc;
        DateTime? endUtc;

        if (ev.startIso8601.isNotEmpty) {
          startUtc = DateTime.tryParse(ev.startIso8601)?.toUtc();
        } else if (dayDate != null) {
          startUtc = dayDate;
        }

        if (ev.endIso8601.isNotEmpty) {
          endUtc = DateTime.tryParse(ev.endIso8601)?.toUtc();
        }

        items.add(
          TimelineEvent(
            dayNumber: day.dayNumber,
            dayTitle: day.title,
            dayDateIso8601: day.dateIso8601,
            event: ev,
            estimatedStartUtc: startUtc,
            estimatedEndUtc: endUtc,
          ),
        );
      }
    }

    items.sort((a, b) {
      if (a.estimatedStartUtc != null && b.estimatedStartUtc != null) {
        return a.estimatedStartUtc!.compareTo(b.estimatedStartUtc!);
      }
      if (a.dayNumber != b.dayNumber) {
        return a.dayNumber.compareTo(b.dayNumber);
      }
      return 0;
    });

    return items;
  }

  /// Get events belonging to a specific itinerary day.
  List<TimelineEvent> getEventsForDay(int dayNumber) {
    return getAllEventsChronological()
        .where((e) => e.dayNumber == dayNumber)
        .toList();
  }

  /// Returns the current ongoing event based on current time.
  TimelineEvent? getCurrentEvent({DateTime? now}) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final events = getAllEventsChronological();
    for (final ev in events) {
      if (ev.getStatus(nowUtc) == TimelineEventStatus.ongoing) {
        return ev;
      }
    }
    return null;
  }

  /// Returns the very next upcoming event.
  TimelineEvent? getNextUpcomingEvent({DateTime? now}) {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final events = getAllEventsChronological();
    for (final ev in events) {
      if (ev.getStatus(nowUtc) == TimelineEventStatus.upcoming) {
        return ev;
      }
    }
    return null;
  }

  /// Calculates the countdown duration to the next upcoming event.
  Duration? getTimeUntilNextEvent({DateTime? now}) {
    final next = getNextUpcomingEvent(now: now);
    if (next == null || next.estimatedStartUtc == null) return null;
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final diff = next.estimatedStartUtc!.difference(nowUtc);
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Returns all transportation legs (Flights, Trains, Buses, Car, Ferry) in order.
  List<TimelineEvent> getTransportationLegs() {
    return getAllEventsChronological()
        .where((e) => e.isFlight || e.isTransport)
        .toList();
  }

  /// Returns all lodging stays.
  List<TimelineEvent> getLodgingStays() {
    return getAllEventsChronological()
        .where((e) => e.isLodging)
        .toList();
  }

  /// Returns all events that have attached vouchers, boarding passes, or documents.
  List<TimelineEvent> getEventsWithAttachments() {
    return getAllEventsChronological()
        .where((e) => e.event.attachmentAssetIds.isNotEmpty)
        .toList();
  }
}
