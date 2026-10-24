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
