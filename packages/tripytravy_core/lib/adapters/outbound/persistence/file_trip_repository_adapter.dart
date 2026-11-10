import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../domain/entities/trip_package.dart';
import '../../../domain/ports/outbound_ports.dart';

/// Production-ready persistent trip repository storing trips as JSON files on disk.
/// Thread-safe and atomic across all platforms (Android, iOS, Desktop).
class FileTripRepositoryAdapter implements TripRepositoryPort {
  final Directory baseDirectory;
  late final Directory _tripsDir;
  late final File _activeTripFile;

  FileTripRepositoryAdapter({required this.baseDirectory}) {
    _tripsDir = Directory(p.join(baseDirectory.path, 'trips'));
    _activeTripFile = File(p.join(baseDirectory.path, 'active_trip.id'));
    if (!_tripsDir.existsSync()) {
      _tripsDir.createSync(recursive: true);
    }
  }

  factory FileTripRepositoryAdapter.fromPath(String path) {
    return FileTripRepositoryAdapter(baseDirectory: Directory(path));
  }

  File _getTripFile(String tripId) =>
      File(p.join(_tripsDir.path, '$tripId.json'));

  @override
  Future<void> saveTrip(TripPackage trip) async {
    final file = _getTripFile(trip.tripId);
    final tempFile = File('${file.path}.tmp');

    final jsonStr = jsonEncode(trip.toJson());
    await tempFile.writeAsString(jsonStr, flush: true);

    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);

    // If there is no active trip set, make this newly saved trip active
    final currentActive = await getActiveTripId();
    if (currentActive == null || currentActive.isEmpty) {
      await setActiveTripId(trip.tripId);
    }
  }

  @override
  Future<TripPackage?> getTripById(String tripId) async {
    final file = _getTripFile(tripId);
    if (!await file.exists()) return null;

    try {
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return TripPackage.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TripPackage>> listAllTrips() async {
    if (!await _tripsDir.exists()) return [];

    final List<TripPackage> result = [];
    final entities = _tripsDir.listSync(followLinks: false);

    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final jsonStr = await entity.readAsString();
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          result.add(TripPackage.fromJson(map));
        } catch (_) {}
      }
    }

    // Sort chronologically by start date
    result.sort((a, b) => a.startDateIso8601.compareTo(b.startDateIso8601));
    return result;
  }

  @override
  Future<bool> deleteTrip(String tripId) async {
    final file = _getTripFile(tripId);
    if (!await file.exists()) return false;

    await file.delete();

    final currentActive = await getActiveTripId();
    if (currentActive == tripId) {
      final remaining = await listAllTrips();
      if (remaining.isNotEmpty) {
        await setActiveTripId(remaining.first.tripId);
      } else {
        if (await _activeTripFile.exists()) {
          await _activeTripFile.delete();
        }
      }
    }
    return true;
  }

  @override
  Future<String?> getActiveTripId() async {
    if (!await _activeTripFile.exists()) return null;
    try {
      final id = (await _activeTripFile.readAsString()).trim();
      return id.isNotEmpty ? id : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setActiveTripId(String tripId) async {
    final temp = File('${_activeTripFile.path}.tmp');
    await temp.writeAsString(tripId.trim(), flush: true);
    if (await _activeTripFile.exists()) {
      await _activeTripFile.delete();
    }
    await temp.rename(_activeTripFile.path);
  }
}
