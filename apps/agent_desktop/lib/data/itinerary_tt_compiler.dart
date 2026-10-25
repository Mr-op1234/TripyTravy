import 'dart:convert';
import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/hexagonal_di_container.dart';
import 'itinerary_database.dart';

/// Compiles agent desktop itinerary data into an encrypted .tt container file (TTRV v1 format).
class ItineraryTtCompiler {
  /// Compiles a DestinationItem with its days, events, and documents into an encrypted .tt binary container.
  static Future<List<int>> compile({
    required DestinationItem trip,
    required List<TripDayItem> days,
    required List<TripEventItem> events,
    required List<TripDocumentItem> documents,
    String? userPin,
    bool isTemplate = false,
    HexagonalDiContainer? diContainer,
  }) async {
    final tripPackage = toTripPackage(
      trip: trip,
      days: days,
      events: events,
      documents: documents,
      isTemplate: isTemplate,
    );

    final di = diContainer ?? HexagonalDiContainer();
    return di.exportTripUseCase.execute(
      trip: tripPackage,
      userPin: userPin,
      exportAsTemplate: isTemplate,
    );
    
  }

  /// Converts desktop database entities into a domain `TripPackage`.
  static TripPackage toTripPackage({
    required DestinationItem trip,
    required List<TripDayItem> days,
    required List<TripEventItem> events,
    required List<TripDocumentItem> documents,
    bool isTemplate = false,
  }) {
    final startIso = (trip.startDate != null && trip.startDate!.trim().isNotEmpty)
        ? trip.startDate!.trim()
        : '2026-11-01';
    final endIso = (trip.endDate != null && trip.endDate!.trim().isNotEmpty)
        ? trip.endDate!.trim()
        : '2026-11-10';

    // Group events by dayId / dayNumber
    final dayMap = <int, List<TripEventItem>>{};
    for (final e in events) {
      final dn = e.dayNumber > 0 ? e.dayNumber : 1;
      dayMap.putIfAbsent(dn, () => []).add(e);
    }

    final mappedDays = <ItineraryDay>[];

    if (days.isNotEmpty) {
      for (final dayItem in days) {
        final dayEvents = events
            .where((e) => e.dayId == dayItem.id || (e.dayId == null && e.dayNumber == dayItem.dayNumber))
            .map((e) => _mapEvent(e, defaultDate: dayItem.date ?? startIso))
            .toList();

        mappedDays.add(
          ItineraryDay(
            dayNumber: dayItem.dayNumber,
            dateIso8601: dayItem.date ?? startIso,
            title: dayItem.title,
            primaryTimezoneIana: 'UTC',
            events: dayEvents,
          ),
        );
      }
    } else if (events.isNotEmpty) {
      // Synthesize days from events
      final sortedDayNumbers = dayMap.keys.toList()..sort();
      for (final dn in sortedDayNumbers) {
        final dayEvents = dayMap[dn]!
            .map((e) => _mapEvent(e, defaultDate: startIso))
            .toList();
        mappedDays.add(
          ItineraryDay(
            dayNumber: dn,
            dateIso8601: startIso,
            title: 'Day $dn',
            primaryTimezoneIana: 'UTC',
            events: dayEvents,
          ),
        );
      }
    } else {
      // Minimum 1 day fallback
      mappedDays.add(
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: startIso,
          title: 'Day 1',
          primaryTimezoneIana: 'UTC',
          events: const [],
        ),
      );
    }

    // Embed documents into an additional Note event or summary if present
    if (documents.isNotEmpty && mappedDays.isNotEmpty) {
      final docEvents = documents.map((doc) {
        return ItineraryEvent(
          eventId: 'doc_event_${doc.id}',
          eventType: EventType.note,
          title: 'Document: ${doc.title}',
          startIso8601: '${startIso}T08:00:00',
          endIso8601: '${startIso}T08:30:00',
          timezoneIana: 'UTC',
          note: NoteDetails(
            severity: NoteSeverity.info,
            categoryLabel: doc.docType.toUpperCase(),
            markdownBody: '${doc.description}\n\nFile: ${doc.fileName} (${doc.fileSize})',
          ),
        );
      }).toList();

      final firstDay = mappedDays.first;
      mappedDays[0] = firstDay.copyWith(
        events: [...docEvents, ...firstDay.events],
      );
    }

    return TripPackage(
      tripId: trip.id.toString(),
      title: trip.title,
      subtitle: trip.effectiveDescription,
      destinationTags: [trip.title],
      startDateIso8601: startIso,
      endDateIso8601: endIso,
      primaryTimezoneIana: 'UTC',
      currencyCodeIso4217: 'USD',
      languageBcp47: 'en-US',
      isTemplate: isTemplate,
      isCompleted: false,
      days: mappedDays,
    );
  }

  static ItineraryEvent _mapEvent(TripEventItem e, {required String defaultDate}) {
    final date = e.eventDate.isNotEmpty ? e.eventDate : defaultDate;
    final startTime = (e.startTime != null && e.startTime!.isNotEmpty) ? e.startTime! : '09:00';
    final endTime = (e.endTime != null && e.endTime!.isNotEmpty) ? e.endTime! : '10:00';

    final startIso = _formatIsoTime(date, startTime);
    final endIso = _formatIsoTime(date, endTime);

    final catLower = e.category.toLowerCase();
    final subCatLower = e.subCategory.toLowerCase();

    EventType type = EventType.activity;
    FlightDetails? flight;
    LodgingDetails? lodging;
    TransportDetails? transport;
    ActivityDetails? activity;
    MealDetails? meal;
    NoteDetails? note;

    if (catLower.contains('flight') || subCatLower.contains('flight')) {
      type = EventType.flight;
      flight = _parseFlight(e);
    } else if (catLower.contains('lodging') ||
        catLower.contains('hotel') ||
        subCatLower.contains('check-in')) {
      type = EventType.lodging;
      lodging = LodgingDetails(
        propertyName: e.locationName ?? e.title,
        address: e.location,
      );
    } else if (catLower.contains('transport') || subCatLower.contains('drive') || subCatLower.contains('train')) {
      type = EventType.transport;
      transport = TransportDetails(
        mode: TransitMode.drive,
        carrierName: e.title,
        pickupLocation: e.location,
        dropoffLocation: e.location,
      );
    } else if (catLower.contains('meal') || catLower.contains('food') || catLower.contains('dine')) {
      type = EventType.meal;
      meal = MealDetails(
        restaurantName: e.locationName ?? e.title,
        address: e.location,
      );
    } else if (catLower.contains('info') || catLower.contains('note')) {
      type = EventType.note;
      note = NoteDetails(
        categoryLabel: e.category,
        markdownBody: e.description,
        checklistItems: e.notes.map((n) => ChecklistItem(itemId: 'note_${n.hashCode}', label: n)).toList(),
      );
    } else {
      type = EventType.activity;
      activity = ActivityDetails(
        meetingPointAddress: e.location,
        durationMinutes: _parseDurationMinutes(e.duration),
      );
    }

    return ItineraryEvent(
      eventId: e.id,
      eventType: type,
      title: e.title,
      startIso8601: startIso,
      endIso8601: endIso,
      timezoneIana: 'UTC',
      flight: flight,
      lodging: lodging,
      transport: transport,
      activity: activity,
      meal: meal,
      note: note,
    );
  }

  static String _formatIsoTime(String date, String time) {
    var cleanTime = time.trim();
    if (cleanTime.length == 5) {
      cleanTime = '$cleanTime:00';
    }
    return '${date}T$cleanTime';
  }

  static int _parseDurationMinutes(String duration) {
    try {
      final digits = duration.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        final val = int.parse(digits);
        if (duration.toLowerCase().contains('hr') || duration.toLowerCase().contains('hour')) {
          return val * 60;
        }
        return val;
      }
    } catch (_) {}
    return 60;
  }

  static FlightDetails _parseFlight(TripEventItem e) {
    if (e.flightDataJson != null && e.flightDataJson!.trim().isNotEmpty) {
      try {
        final map = jsonDecode(e.flightDataJson!) as Map<String, dynamic>;
        return FlightDetails(
          airlineName: (map['airlineName'] as String?) ?? e.title,
          flightNumber: (map['flightNumber'] as String?) ?? '',
          departureIata: (map['departureIata'] as String?) ?? 'CCU',
          arrivalIata: (map['arrivalIata'] as String?) ?? 'DXB',
          departureTimezoneIana: 'UTC',
          arrivalTimezoneIana: 'UTC',
          terminal: (map['terminal'] as String?) ?? '',
          gate: (map['gate'] as String?) ?? '',
          seatNumber: (map['seatNumber'] as String?) ?? '',
          pnrConfirmationCode: (map['pnr'] as String?) ?? '',
        );
      } catch (_) {}
    }
    return FlightDetails(
      airlineName: e.title,
      flightNumber: '',
      departureIata: 'DEP',
      arrivalIata: 'ARR',
      departureTimezoneIana: 'UTC',
      arrivalTimezoneIana: 'UTC',
    );
  }
}
