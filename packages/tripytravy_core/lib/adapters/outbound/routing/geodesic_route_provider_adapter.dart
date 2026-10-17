import 'dart:math' as math;
import '../../../domain/entities/itinerary_event.dart';
import '../../../domain/value_objects/geo_coordinate.dart';
import '../../../domain/ports/outbound_ports.dart';

class GeodesicRouteProviderAdapter implements RouteProviderPort {
  const GeodesicRouteProviderAdapter();
  static double haversineKm(GeoCoordinate a, GeoCoordinate b) {
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.latitude * math.pi / 180.0) * math.cos(b.latitude * math.pi / 180.0) * math.pow(math.sin(dLon / 2), 2);
    return 12742.0 * math.asin(math.sqrt(h));
  }
  @override
  Future<RoutePath> computeRoute({
    required String routeId,
    required String fromEventId,
    required String toEventId,
    required GeoCoordinate origin,
    required GeoCoordinate destination,
    required TransitMode mode,
  }) async {
    final km = haversineKm(origin, destination);
    final spd = mode == TransitMode.walk ? 4.5 : (mode == TransitMode.rail ? 85.0 : 55.0);
    return RoutePath(
      routeId: routeId,
      fromEventId: fromEventId,
      toEventId: toEventId,
      transitMode: mode,
      distanceKm: double.parse(km.toStringAsFixed(2)),
      durationMinutes: math.max(1, ((km / spd) * 60).round()),
    );
  }
}
