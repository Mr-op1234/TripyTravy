import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  late Directory tempDir;
  late MobileTripManagerService manager;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tripy_manager_test_');
    manager = MobileTripManagerService.fromDirectory(tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  const legacyKashmir = TripPackage(
    tripId: '4',
    title: 'Kashmir',
    startDateIso8601: '2026-11-25',
    endDateIso8601: '2026-11-29',
    primaryTimezoneIana: 'Asia/Kolkata',
    days: [
      ItineraryDay(
        dayNumber: 1,
        dateIso8601: '2026-11-25',
        title: 'Arrival',
        primaryTimezoneIana: 'Asia/Kolkata',
        events: [
          ItineraryEvent(
            eventId: 'evt_4_1793281756087',
            title: 'Airport pickup',
            eventType: EventType.transport,
            startIso8601: '2026-11-25T09:00:00',
            endIso8601: '2026-11-25T10:00:00',
            timezoneIana: 'Asia/Kolkata',
          ),
        ],
      ),
    ],
  );
  const exportId = 'tt_44d3eba4601175df166784594a9fb318';

  test('updated exports replace the matching trip and preserve local state',
      () async {
    final oldFile = await manager.exportTripUseCase.execute(trip: legacyKashmir);
    await manager.importTripFromContainer(oldFile);
    await manager.tripRepository.saveTrip(legacyKashmir.copyWith(isCompleted: true));
    await manager.toggleChecklistItem('4', 'chk_passport', true);

    final first = legacyKashmir.copyWith(
      tripId: exportId,
      legacyTripId: '4',
      revision: 1,
      title: 'Kashmir revised',
    );
    final revisionOne = await manager.exportTripUseCase.execute(trip: first);
    await manager.importTripFromContainer(revisionOne);
    expect(await manager.tripRepository.getTripById('4'), isNull);
    expect((await manager.getChecklist(exportId)).completedCount, 1);

    final revisionTwo = await manager.exportTripUseCase.execute(
      trip: first.copyWith(revision: 2, title: 'Kashmir revised again'),
    );
    final restarted = MobileTripManagerService.fromDirectory(tempDir);
    await Future.wait([
      restarted.importTripFromContainer(revisionTwo),
      restarted.importTripFromContainer(revisionOne),
      restarted.importTripFromContainer(oldFile),
    ]);

    final saved = (await restarted.listAllTrips()).single;
    expect(saved.tripId, exportId);
    expect(saved.title, 'Kashmir revised again');
    expect(saved.revision, 2);
    expect(saved.isCompleted, isTrue);
    expect((await restarted.getChecklist(exportId)).completedCount, 1);
    expect((await restarted.getActiveTrip())?.tripId, exportId);
  });

  test('a different itinerary keeps its own entry despite a matching legacy ID',
      () async {
    await manager.tripRepository.saveTrip(legacyKashmir);
    final unrelated = legacyKashmir.copyWith(
      tripId: exportId,
      legacyTripId: '4',
      revision: 1,
      days: [],
    );
    final bytes = await manager.exportTripUseCase.execute(trip: unrelated);
    await manager.importTripFromContainer(bytes);
    expect((await manager.listAllTrips()).map((trip) => trip.tripId),
        unorderedEquals(['4', exportId]));
  });

  test('a revision with an invalid identity cannot replace a saved trip',
      () async {
    await manager.tripRepository.saveTrip(legacyKashmir);
    final invalid = legacyKashmir.copyWith(revision: 1, title: 'Invalid revision');
    final bytes = await manager.exportTripUseCase.execute(trip: invalid);
    await expectLater(manager.importTripFromContainer(bytes), throwsFormatException);
    expect((await manager.listAllTrips()).single.title, 'Kashmir');
  });

  test('full offline trip container import, export, and checklist lifecycle',
      () async {
    // 1. Create a trip with an attached photo blob
    final photoBytes = utf8.encode('PNG_IMAGE_BYTES_MOCK_DATA_12345');
    const attachment = AttachmentDescriptor(
      assetId: 'asset_eiffel_tower',
      filename: 'eiffel.png',
      mimeType: 'image/png',
      category: AttachmentCategory.photoGallery,
      visibility: AttachmentVisibility.templateSafe,
      byteSize: 32,
      sha256Checksum:
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      byteOffset: 0,
    );

    await manager.attachmentStorage
        .putRawBlob(attachment.sha256Checksum, photoBytes);

    const trip = TripPackage(
      tripId: 'trip_france_2026',
      title: 'France Summer Tour',
      subtitle: 'Paris & Nice',
      startDateIso8601: '2026-07-10',
      endDateIso8601: '2026-07-20',
      primaryTimezoneIana: 'Europe/Paris',
      allAssets: [attachment],
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-07-10',
          title: 'Arrival in Paris',
          primaryTimezoneIana: 'Europe/Paris',
          events: [
            ItineraryEvent(
              eventId: 'ev_eiffel',
              title: 'Visit Eiffel Tower',
              eventType: EventType.activity,
              startIso8601: '2026-07-10T16:00:00Z',
              endIso8601: '2026-07-10T18:00:00Z',
              timezoneIana: 'Europe/Paris',
              attachmentAssetIds: ['asset_eiffel_tower'],
              activity: ActivityDetails(
                meetingPointAddress: 'Champ de Mars, Paris',
                durationMinutes: 120,
              ),
            ),
          ],
        ),
      ],
    );

    // Save initial trip
    await manager.tripRepository.saveTrip(trip);

    // 2. Export to encrypted .ttrv container with PIN
    final ttrvBytes = await manager.exportTripToContainer(
      'trip_france_2026',
      userPin: '8899',
    );
    expect(ttrvBytes.length, greaterThan(56));

    // 3. Create a fresh second manager in a different directory (simulating another device!)
    final device2Dir =
        Directory.systemTemp.createTempSync('tripy_device2_test_');
    try {
      final device2Manager =
          MobileTripManagerService.fromDirectory(device2Dir);

      // Attempt import with wrong PIN -> fails
      expect(
        () => device2Manager.importTripFromContainer(ttrvBytes,
            userPin: 'wrong_pin'),
        throwsA(isA<StateError>()),
      );

      // Import with correct PIN
      final importedTrip = await device2Manager.importTripFromContainer(
        ttrvBytes,
        userPin: '8899',
      );

      expect(importedTrip.tripId, 'trip_france_2026');
      expect(importedTrip.title, 'France Summer Tour');
      expect(importedTrip.allAssets.length, 1);

      // Verify active trip
      final active = await device2Manager.getActiveTrip();
      expect(active, isNotNull);
      expect(active!.tripId, 'trip_france_2026');

      // Verify unpacked asset blob was persisted to local storage
      final blobBytes = await device2Manager
          .getAttachmentBytes(attachment.sha256Checksum);
      expect(blobBytes, isNotNull);
      expect(utf8.decode(blobBytes!), 'PNG_IMAGE_BYTES_MOCK_DATA_12345');

      // 4. Test checklist persistence on device 2
      final initialChecklist =
          await device2Manager.getChecklist('trip_france_2026');
      expect(initialChecklist.completedCount, 0);

      // Check an item
      final updatedChecklist = await device2Manager.toggleChecklistItem(
        'trip_france_2026',
        'chk_passport',
        true,
      );
      expect(updatedChecklist.completedCount, 1);

      // Reloading from device 2 shows item is still checked
      final reloadedChecklist =
          await device2Manager.getChecklist('trip_france_2026');
      expect(reloadedChecklist.completedCount, 1);

      // 5. Test timeline navigation
      final timeline = await device2Manager
          .getTimelineService('trip_france_2026');
      expect(timeline, isNotNull);
      expect(timeline!.getAllEventsChronological().length, 1);
    } finally {
      if (device2Dir.existsSync()) {
        device2Dir.deleteSync(recursive: true);
      }
    }
  });
}
