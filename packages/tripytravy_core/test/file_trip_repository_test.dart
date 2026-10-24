import 'dart:io';
import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  late Directory tempDir;
  late FileTripRepositoryAdapter repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('tripy_repo_test_');
    repo = FileTripRepositoryAdapter(baseDirectory: tempDir);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('saves and retrieves trip package from disk', () async {
    const trip = TripPackage(
      tripId: 'trip_bali_2026',
      title: 'Bali Adventure',
      subtitle: 'Tropical Escape',
      startDateIso8601: '2026-11-01',
      endDateIso8601: '2026-11-07',
      primaryTimezoneIana: 'Asia/Makassar',
    );

    await repo.saveTrip(trip);

    final retrieved = await repo.getTripById('trip_bali_2026');
    expect(retrieved, isNotNull);
    expect(retrieved!.tripId, 'trip_bali_2026');
    expect(retrieved.title, 'Bali Adventure');
    expect(retrieved.subtitle, 'Tropical Escape');
    expect(retrieved.primaryTimezoneIana, 'Asia/Makassar');
  });

  test('auto sets active trip on first save and lists sorted trips', () async {
    const trip1 = TripPackage(
      tripId: 'trip_tokyo',
      title: 'Tokyo Trip',
      startDateIso8601: '2026-12-10',
      endDateIso8601: '2026-12-18',
      primaryTimezoneIana: 'Asia/Tokyo',
    );
    const trip2 = TripPackage(
      tripId: 'trip_paris',
      title: 'Paris Getaway',
      startDateIso8601: '2026-09-01',
      endDateIso8601: '2026-09-08',
      primaryTimezoneIana: 'Europe/Paris',
    );

    await repo.saveTrip(trip1);
    expect(await repo.getActiveTripId(), 'trip_tokyo');

    await repo.saveTrip(trip2);
    // Active trip remains trip_tokyo until changed
    expect(await repo.getActiveTripId(), 'trip_tokyo');

    final trips = await repo.listAllTrips();
    expect(trips.length, 2);
    // Chronologically sorted: Paris (Sept) before Tokyo (Dec)
    expect(trips[0].tripId, 'trip_paris');
    expect(trips[1].tripId, 'trip_tokyo');

    // Switch active
    await repo.setActiveTripId('trip_paris');
    expect(await repo.getActiveTripId(), 'trip_paris');
  });

  test('deletes trip and automatically reassigns active trip', () async {
    const tripA = TripPackage(
      tripId: 'trip_a',
      title: 'Trip A',
      startDateIso8601: '2026-05-01',
      endDateIso8601: '2026-05-05',
      primaryTimezoneIana: 'UTC',
    );
    const tripB = TripPackage(
      tripId: 'trip_b',
      title: 'Trip B',
      startDateIso8601: '2026-06-01',
      endDateIso8601: '2026-06-05',
      primaryTimezoneIana: 'UTC',
    );

    await repo.saveTrip(tripA);
    await repo.saveTrip(tripB);
    await repo.setActiveTripId('trip_a');

    final deleted = await repo.deleteTrip('trip_a');
    expect(deleted, isTrue);
    expect(await repo.getTripById('trip_a'), isNull);

    // Should have reassigned to trip_b
    expect(await repo.getActiveTripId(), 'trip_b');
  });
}
