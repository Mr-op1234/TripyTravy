import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

import '../di/hexagonal_di_container.dart';
import 'itinerary_database.dart';

class ItineraryTtImporter {
  Future<DestinationItem> import(List<int> bytes, {String? pin}) async {
    final di = HexagonalDiContainer();
    final trip = bytes.length >= 4 &&
            ascii.decode(bytes.take(4).toList(), allowInvalid: true) == 'TTRV'
        ? await di.importTripUseCase
            .execute(containerBytes: bytes, userPin: pin)
        : TripPackage.fromJson(
            jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    if (trip.title.trim().isEmpty) {
      throw const FormatException('The itinerary is missing its title.');
    }

    final support = await getApplicationSupportDirectory();
    final imports =
        await Directory(p.join(support.path, 'TripyTravy', 'imports'))
            .create(recursive: true);
    final folder = await imports.createTemp('trip-');
    final media = _ImportedMedia(folder, di.attachmentStorage, trip.allAssets);
    try {
      final banner = await media.image(trip.bannerImage);
      final database = ItineraryDatabase.instance;
      final db = await database.database;
      return await db.transaction((transaction) async {
        final dates = [trip.startDateIso8601, trip.endDateIso8601]
            .where((date) => date.isNotEmpty);
        final row = DestinationItem(
          id: 0,
          title: trip.title,
          subtitle: trip.subtitle,
          description: trip.subtitle,
          duration:
              '${trip.days.length} ${trip.days.length == 1 ? 'Day' : 'Days'}',
          dateRange: dates.toSet().join(' – '),
          startDate: trip.startDateIso8601,
          endDate: trip.endDateIso8601,
          imagePath: banner ?? '',
        ).toMap()
          ..remove('id');
        final id = await transaction.insert('itineraries', row);
        final eventDocumentIds = <String>{};
        var documentIndex = 0;
        var dayIndex = 0;
        for (final day in trip.days) {
          final dayId = 'import_${id}_day_${dayIndex++}';
          await transaction.insert(
              'itinerary_days',
              TripDayItem(
                id: dayId,
                itineraryId: id,
                dayNumber: day.dayNumber,
                title: day.title,
                date: day.dateIso8601,
                description: day.description,
                sortOrder: dayIndex,
              ).toMap());
          var eventIndex = 0;
          for (final event in day.events) {
            // Desktop exports include generated timeline summaries for trip documents.
            if (event.eventId.startsWith('doc_event_') &&
                event.eventType == EventType.note &&
                event.title.startsWith('Document: ')) {
              continue;
            }
            final photos = <String>[];
            for (final photo in event.photos) {
              final path = await media.image(photo);
              if (path != null) photos.add(path);
            }
            final attachments = <Map<String, String>>[];
            for (final doc in event.documents) {
              if (doc.id.isNotEmpty) eventDocumentIds.add(doc.id);
              final path = await media.document(doc);
              if (path != null) {
                attachments.add(
                    {'name': doc.fileName, 'size': doc.fileSize, 'path': path});
              }
            }
            final start = DateTime.tryParse(event.startIso8601);
            final end = DateTime.tryParse(event.endIso8601);
            final duration = start == null || end == null
                ? 0
                : end.difference(start).inMinutes;
            final flight = event.flight;
            await database.insertEvent(
                TripEventItem(
                  id: '${dayId}_event_${eventIndex++}',
                  itineraryId: id,
                  dayId: dayId,
                  dayNumber: day.dayNumber,
                  title: event.title,
                  eventDate: day.dateIso8601,
                  startTime: _time(event.startIso8601),
                  endTime: _time(event.endIso8601),
                  duration: duration > 0 ? '$duration min' : '',
                  location: event.locationName ?? '',
                  description: event.description.isNotEmpty
                      ? event.description
                      : event.note?.markdownBody ?? '',
                  photos: photos,
                  notes: event.note?.checklistItems
                          .map((item) => item.label)
                          .toList() ??
                      const [],
                  sortOrder: eventIndex,
                  locationName: event.locationName,
                  latitude: event.latitude,
                  longitude: event.longitude,
                  mapUrl: event.mapUrl,
                  locationsJson: event.locationsJson,
                  category: event.category.isNotEmpty
                      ? event.category
                      : switch (event.eventType) {
                          EventType.flight ||
                          EventType.transport =>
                            'Transportation',
                          EventType.lodging => 'Lodging',
                          EventType.meal => 'Meal',
                          EventType.note => 'Info',
                          EventType.activity => 'Activity',
                        },
                  subCategory: event.subCategory.isEmpty && flight != null
                      ? 'Flight'
                      : event.subCategory,
                  subDetail: event.subDetail,
                  flightDataJson: flight == null
                      ? null
                      : jsonEncode({
                          ...flight.toJson(),
                          'pnr': flight.pnrConfirmationCode,
                          'from': flight.departureIata,
                          'to': flight.arrivalIata,
                          'airline': flight.airlineName,
                          'flightNo': flight.flightNumber,
                          'seat': flight.seatNumber,
                          'bookingCode': flight.pnrConfirmationCode,
                        }),
                  attachmentsJson:
                      attachments.isEmpty ? null : jsonEncode(attachments),
                ),
                transaction: transaction);
          }
        }
        for (final doc in trip.documents) {
          if (eventDocumentIds.contains(doc.id)) continue;
          await database.insertDocument(
              TripDocumentItem(
                id: 'import_${id}_doc_${documentIndex++}',
                itineraryId: id,
                title: doc.title,
                docType: doc.docType,
                description: doc.description,
                fileName: doc.fileName,
                fileSize: doc.fileSize,
                filePath: await media.document(doc) ?? '',
                locationName: doc.locationName,
                mapUrl: doc.mapUrl,
              ),
              transaction: transaction);
        }
        return DestinationItem.fromMap({...row, 'id': id});
      });
    } catch (_) {
      await media.discard();
      rethrow;
    }
  }

  static String? _time(String value) =>
      RegExp(r'T(\d{2}:\d{2})').firstMatch(value)?.group(1);
}

class _ImportedMedia {
  final Directory folder;
  final AttachmentStoragePort storage;
  final List<AttachmentDescriptor> assets;
  final _files = <File>[];

  _ImportedMedia(this.folder, this.storage, this.assets);

  Future<String?> image(String source) async {
    if (source.startsWith('data:image/')) {
      return _write(UriData.parse(source).contentAsBytes(), 'image.jpg');
    }
    if (source.startsWith('asset:')) {
      final hash = source.substring(6);
      final bytes = await storage.readBlobBySha256(hash);
      if (bytes == null)
        throw const FormatException('An itinerary photo is missing.');
      final asset = assets.firstWhere((asset) => asset.sha256Checksum == hash);
      return _write(bytes, asset.filename);
    }
    final scheme = Uri.tryParse(source)?.scheme;
    return scheme == 'https' || scheme == 'http' ? source : null;
  }

  Future<String?> document(TripDocumentRecord doc) async {
    final hash = doc.assetSha256;
    if (hash != null && hash.isNotEmpty) {
      final bytes = await storage.readBlobBySha256(hash);
      if (bytes == null)
        throw const FormatException('An itinerary document is missing.');
      return _write(bytes, doc.fileName);
    }
    final embedded = doc.base64Data;
    return embedded == null || embedded.isEmpty
        ? null
        : _write(base64Decode(embedded), doc.fileName);
  }

  Future<String> _write(List<int> bytes, String name) async {
    final extension = p.extension(name);
    final suffix =
        RegExp(r'^\.[a-zA-Z0-9]{1,10}$').hasMatch(extension) ? extension : '';
    final file =
        File(p.join(folder.path, 'attachment_${_files.length}$suffix'));
    _files.add(file);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> discard() async {
    for (final file in _files) {
      if (await file.exists()) await file.delete();
    }
    await folder.delete();
  }
}
