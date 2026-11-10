import 'dart:convert';
import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  test('photos and non-PDF documents reuse their content across cards', () async {
    final photoBytes = utf8.encode('identical image bytes');
    final image = 'data:image/png;base64,${base64Encode(photoBytes)}';
    final document = TripDocumentRecord(id: 'sheet', title: 'Sheet', fileName: 'hotels.xlsx', base64Data: base64Encode(utf8.encode('spreadsheet')));
    ItineraryEvent event(String id) => ItineraryEvent(eventId: id, title: id, eventType: EventType.activity, startIso8601: '', endIso8601: '', timezoneIana: 'UTC', photos: [image, image], documents: [document]);
    final trip = TripPackage(tripId: 'photos', title: 'Photos', startDateIso8601: '', endDateIso8601: '', primaryTimezoneIana: 'UTC', days: [ItineraryDay(dayNumber: 1, dateIso8601: '', title: 'Day', primaryTimezoneIana: 'UTC', events: [event('one'), event('two')])]);
    final storage = CasAttachmentStorageAdapter();
    final bytes = await ExportTripContainerUseCase(storage: storage, cipher: const TtrvContainerCipherAdapter()).execute(trip: trip);
    final importedStorage = CasAttachmentStorageAdapter();
    final restored = await ImportTripContainerUseCase(storage: importedStorage, cipher: const TtrvContainerCipherAdapter()).execute(containerBytes: bytes);
    expect(restored.allAssets, hasLength(2));
    final events = restored.days.first.events;
    expect(events.first.photos, hasLength(1));
    expect(events.first.photos, events.last.photos);
    expect(await importedStorage.readBlobBySha256(events.first.photos.single.substring(6)), photoBytes);
    expect(events.first.documents.single.assetSha256, events.last.documents.single.assetSha256);
    final repacked = await ExportTripContainerUseCase(storage: importedStorage, cipher: const TtrvContainerCipherAdapter()).execute(trip: restored);
    expect((await const TtrvContainerCipherAdapter().unpackContainer(containerBytes: repacked)).concatenatedAssets.length, photoBytes.length + utf8.encode('spreadsheet').length);
  });
  test('renamed copies share one binary payload across cards and roundtrip', () async {
    final bytes = List<int>.generate(1024 * 1024, (index) => index % 256);
    TripDocumentRecord doc(String name, {String? content}) => TripDocumentRecord(id: name, title: name, fileName: name, base64Data: content ?? base64Encode(bytes));
    ItineraryEvent event(String id, List<TripDocumentRecord> docs) => ItineraryEvent(eventId: id, title: id, eventType: EventType.lodging, startIso8601: '2026-11-09T09:00:00', endIso8601: '2026-11-09T10:00:00', timezoneIana: 'UTC', documents: docs);
    final trip = TripPackage(tripId: 'test', title: 'Hotels', startDateIso8601: '2026-11-09', endDateIso8601: '2026-11-09', primaryTimezoneIana: 'UTC', documents: [doc('overview.pdf')], days: [ItineraryDay(dayNumber: 1, dateIso8601: '2026-11-09', title: 'Hotels', primaryTimezoneIana: 'UTC', events: [event('hotel-one', [doc('first.pdf'), doc('duplicate.pdf')]), event('hotel-two', [doc('renamed.pdf')])])]);
    final storage = CasAttachmentStorageAdapter();
    final export = ExportTripContainerUseCase(storage: storage, cipher: const TtrvContainerCipherAdapter());
    final packed = await export.execute(trip: trip);
    expect(packed.length, lessThan(bytes.length + 10000));
    final inner = await const TtrvContainerCipherAdapter().unpackContainer(containerBytes: packed);
    expect(inner.concatenatedAssets, bytes);
    final importedStorage = CasAttachmentStorageAdapter();
    final restored = await ImportTripContainerUseCase(storage: importedStorage, cipher: const TtrvContainerCipherAdapter()).execute(containerBytes: packed);
    expect(restored.allAssets, hasLength(1));
    final first = restored.days.first.events.first.documents.single;
    final second = restored.days.first.events.last.documents.single;
    expect(first.assetSha256, second.assetSha256);
    expect(first.fileName, 'first.pdf');
    expect(second.fileName, 'renamed.pdf');
    expect(first.base64Data, isNull);
    expect(await importedStorage.readBlobBySha256(first.assetSha256!), bytes);
    final again = await ExportTripContainerUseCase(storage: importedStorage, cipher: const TtrvContainerCipherAdapter()).execute(trip: restored);
    expect((await const TtrvContainerCipherAdapter().unpackContainer(containerBytes: again)).concatenatedAssets, bytes);
    final different = trip.copyWith(documents: [doc('overview.pdf', content: base64Encode(utf8.encode('different contents')))]);
    final unpackedDifferent = await const TtrvContainerCipherAdapter().unpackContainer(containerBytes: await export.execute(trip: different));
    expect(const ProtobufTripMapper().fromWireBytes(unpackedDifferent.protobufBytes).allAssets, hasLength(2));
  });
}
