import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import 'package:client_mobile/di/mobile_di_container.dart';

void main() {
  late Directory tempDir;
  late MobileDiContainer mobileDi;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mobile_tt_import_test_');
    mobileDi = MobileDiContainer.persistent(tempDir);
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('Cross-platform .tt compilation and mobile interpreter roundtrip test', () async {
    // 1. Desktop Compiler simulation: Create TripPackage with Day descriptions and documents
    const testDoc = TripDocumentRecord(
      id: 'doc_123',
      title: 'JR Rail Pass Voucher',
      docType: 'Transport',
      description: 'Exchange order for 7-day all Japan rail pass',
      fileName: 'jr_pass.pdf',
      fileSize: '450 KB',
      locationName: 'Shin-Osaka Station',
    );

    const trip = TripPackage(
      tripId: 'trip_compiled_osaka',
      title: 'Osaka Adventure',
      subtitle: 'Street food and castle historical walk',
      startDateIso8601: '2026-11-01',
      endDateIso8601: '2026-11-04',
      primaryTimezoneIana: 'Asia/Tokyo',
      documents: [testDoc],
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-11-01',
          title: 'Arrival & Dotonbori',
          description: 'Check in to hotel and evening neon food walk.',
          primaryTimezoneIana: 'Asia/Tokyo',
          events: [
            ItineraryEvent(
              eventId: 'ev_1',
              title: 'Dotonbori Street Food Tour',
              eventType: EventType.activity,
              startIso8601: '2026-11-01T18:00:00Z',
              endIso8601: '2026-11-01T21:00:00Z',
              timezoneIana: 'Asia/Tokyo',
            ),
          ],
        ),
      ],
    );

    // 2. Export / Compile into .tt encrypted binary format using core export usecase
    const cipher = TtrvContainerCipherAdapter();
    const mapper = ProtobufTripMapper();
    final wireBytes = mapper.toWireBytes(trip);
    final compiledTtBytes = await cipher.packContainer(
      protobufBytes: wireBytes,
      concatenatedAssets: [],
      userPin: '1234',
    );

    // Verify .tt container has TTRV magic and flags
    expect(compiledTtBytes.length, greaterThan(56));
    expect(compiledTtBytes[0], 0x54); // 'T'
    expect(compiledTtBytes[1], 0x54); // 'T'
    expect(compiledTtBytes[2], 0x52); // 'R'
    expect(compiledTtBytes[3], 0x56); // 'V'

    // 3. Mobile Interpreter: Import into Mobile Trip Manager
    // Wrong PIN should fail authentication
    expect(
      () => mobileDi.tripManager.importTripFromContainer(compiledTtBytes, userPin: 'wrong_pin'),
      throwsA(isA<StateError>()),
    );

    // Correct PIN should succeed and persist into mobile database
    final imported = await mobileDi.tripManager.importTripFromContainer(
      compiledTtBytes,
      userPin: '1234',
    );

    // 4. Verify decoded data fidelity on mobile side
    expect(imported.tripId, 'trip_compiled_osaka');
    expect(imported.title, 'Osaka Adventure');
    expect(imported.subtitle, 'Street food and castle historical walk');
    expect(imported.days.length, 1);
    expect(imported.days.first.title, 'Arrival & Dotonbori');
    expect(imported.days.first.description, 'Check in to hotel and evening neon food walk.');
    expect(imported.documents.length, 1);
    expect(imported.documents.first.title, 'JR Rail Pass Voucher');
    expect(imported.documents.first.locationName, 'Shin-Osaka Station');

    // 5. Verify it is persisted and retrievable via mobile repository
    final active = await mobileDi.tripManager.getActiveTrip();
    expect(active, isNotNull);
    expect(active!.tripId, 'trip_compiled_osaka');
  });
}
