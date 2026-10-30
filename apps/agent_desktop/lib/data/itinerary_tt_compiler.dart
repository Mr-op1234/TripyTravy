import 'dart:convert';
import 'dart:io';
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
        String dayDateIso = startIso;
        if (dayItem.date != null && dayItem.date!.trim().isNotEmpty) {
          final raw = dayItem.date!.trim();
          final parsed = DateTime.tryParse(raw);
          if (parsed != null) {
            dayDateIso = parsed.toIso8601String().split('T').first;
          } else {
            final parts = raw.split(RegExp(r'[-/]'));
            if (parts.length == 3 && parts[2].length == 4) {
              dayDateIso =
                  '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
            }
          }
        }

        final dayEvents = events
            .where((e) =>
                e.dayId == dayItem.id ||
                (e.dayId == null && e.dayNumber == dayItem.dayNumber))
            .map((e) => _mapEvent(e, defaultDate: dayDateIso))
            .toList();

        mappedDays.add(
          ItineraryDay(
            dayNumber: dayItem.dayNumber,
            dateIso8601: dayDateIso,
            title: dayItem.title,
            description: dayItem.description ?? '',
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
            description: '',
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
          description: '',
          primaryTimezoneIana: 'UTC',
          events: const [],
        ),
      );
    }

    // Map documents into domain documents
    final mappedDocs = <TripDocumentRecord>[];
    for (final doc in documents) {
      if (doc.attachments.isNotEmpty) {
        for (var i = 0; i < doc.attachments.length; i++) {
          final att = doc.attachments[i];
          final name = att['name'] ?? doc.fileName;
          final size = att['size'] ?? doc.fileSize;
          final path = att['path'] ?? doc.filePath;
          final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'DOC';
          final docType = ext == 'PDF' ? 'PDF Document' : '$ext Document';

          String? base64Data;
          if (path.isNotEmpty) {
            try {
              final file = File(path);
              if (file.existsSync()) {
                final bytes = file.readAsBytesSync();
                if (bytes.length <= 10 * 1024 * 1024) {
                  base64Data = base64Encode(bytes);
                }
              }
            } catch (_) {}
          }

          mappedDocs.add(
            TripDocumentRecord(
              id: '${doc.id}_$i',
              title: name,
              docType: docType,
              description: doc.description,
              fileName: name,
              fileSize: size,
              filePath: path,
              locationName: doc.locationName,
              mapUrl: doc.mapUrl,
              base64Data: base64Data,
            ),
          );
        }
      } else {
        String? base64Data;
        if (doc.filePath.isNotEmpty) {
          try {
            final file = File(doc.filePath);
            if (file.existsSync()) {
              final bytes = file.readAsBytesSync();
              if (bytes.length <= 10 * 1024 * 1024) {
                base64Data = base64Encode(bytes);
              }
            }
          } catch (_) {}
        }
        mappedDocs.add(
          TripDocumentRecord(
            id: doc.id,
            title: doc.title,
            docType: doc.docType,
            description: doc.description,
            fileName: doc.fileName,
            fileSize: doc.fileSize,
            filePath: doc.filePath,
            locationName: doc.locationName,
            mapUrl: doc.mapUrl,
            base64Data: base64Data,
          ),
        );
      }
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

    // Collect all documents including event-level attachments
    final allDocs = <TripDocumentRecord>[...mappedDocs];
    for (final day in mappedDays) {
      for (final ev in day.events) {
        for (final edoc in ev.documents) {
          if (!allDocs.any((d) => d.id == edoc.id || (d.fileName.isNotEmpty && d.fileName == edoc.fileName))) {
            allDocs.add(edoc);
          }
        }
      }
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
      documents: allDocs,
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

    // Process photos (embed local photos as base64 data URIs so they travel in .tt offline)
    final mappedPhotos = <String>[];
    for (final p in e.photos) {
      if (p.startsWith('http://') || p.startsWith('https://') || p.startsWith('data:image/')) {
        mappedPhotos.add(p);
      } else {
        try {
          final file = File(p);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.length <= 4 * 1024 * 1024) {
              final ext = p.split('.').last.toLowerCase();
              final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
              mappedPhotos.add('data:$mime;base64,${base64Encode(bytes)}');
              continue;
            }
          }
        } catch (_) {}
        mappedPhotos.add(p);
      }
    }

    // Process event attachments (vouchers, passes, PDFs)
    final mappedEventDocs = <TripDocumentRecord>[];
    final rawAttachments = e.attachments;
    for (var i = 0; i < rawAttachments.length; i++) {
      final att = rawAttachments[i];
      final name = att['name'] ?? 'Document';
      final size = att['size'] ?? '';
      final path = att['path'] ?? '';
      final ext = name.contains('.') ? name.split('.').last.toUpperCase() : 'DOC';
      final docType = ext == 'PDF' ? 'PDF Document' : '$ext Document';

      String? base64Data;
      if (path.isNotEmpty) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            if (bytes.length <= 10 * 1024 * 1024) {
              base64Data = base64Encode(bytes);
            }
          }
        } catch (_) {}
      }

      mappedEventDocs.add(
        TripDocumentRecord(
          id: 'att_${e.id}_$i',
          title: name,
          docType: docType,
          description: 'Document attached to ${e.title}',
          fileName: name,
          fileSize: size,
          filePath: path,
          locationName: e.locationName ?? e.location,
          mapUrl: e.mapUrl,
          base64Data: base64Data,
        ),
      );
    }

    return ItineraryEvent(
      eventId: e.id,
      eventType: type,
      title: e.title,
      startIso8601: startIso,
      endIso8601: endIso,
      timezoneIana: 'UTC',
      category: e.category,
      subCategory: e.subCategory,
      subDetail: e.subDetail,
      description: e.description,
      photos: mappedPhotos,
      documents: mappedEventDocs,
      flight: flight,
      lodging: lodging,
      transport: transport,
      activity: activity,
      meal: meal,
      note: note,
      locationName: e.locationName ?? (e.location.isNotEmpty ? e.location : null),
      mapUrl: e.mapUrl,
      latitude: e.latitude,
      longitude: e.longitude,
      locationsJson: e.locationsJson,
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
