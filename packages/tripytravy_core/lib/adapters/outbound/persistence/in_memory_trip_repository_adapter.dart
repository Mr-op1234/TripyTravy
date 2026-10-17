import '../../../domain/entities/trip_package.dart';
import '../../../domain/ports/outbound_ports.dart';

class InMemoryTripRepositoryAdapter implements TripRepositoryPort {
  final Map<String, TripPackage> _s = {};
  @override
  Future<void> saveTrip(TripPackage t) async => _s[t.tripId] = t;
  @override
  Future<TripPackage?> getTripById(String id) async => _s[id];
  @override
  Future<List<TripPackage>> listAllTrips() async => _s.values.toList(growable: false);
}
