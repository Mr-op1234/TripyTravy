import '../../../domain/entities/trip_package.dart';
import '../../../domain/ports/outbound_ports.dart';

class InMemoryTripRepositoryAdapter implements TripRepositoryPort {
  final Map<String, TripPackage> _s = {};
  String? _activeTripId;

  @override
  Future<void> saveTrip(TripPackage t) async {
    _s[t.tripId] = t;
    _activeTripId ??= t.tripId;
  }

  @override
  Future<TripPackage?> getTripById(String id) async => _s[id];

  @override
  Future<List<TripPackage>> listAllTrips() async =>
      _s.values.toList(growable: false);

  @override
  Future<bool> deleteTrip(String tripId) async {
    final removed = _s.remove(tripId) != null;
    if (_activeTripId == tripId) {
      _activeTripId = _s.keys.isNotEmpty ? _s.keys.first : null;
    }
    return removed;
  }

  @override
  Future<String?> getActiveTripId() async => _activeTripId;

  @override
  Future<void> setActiveTripId(String tripId) async {
    _activeTripId = tripId;
  }
}
