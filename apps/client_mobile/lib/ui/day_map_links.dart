import 'package:tripytravy_core/tripytravy_core.dart';

class DayMapStop {
  final String label;
  final String query;
  const DayMapStop(this.label, this.query);
}

List<DayMapStop> dayMapStops(ItineraryDay day) {
  final stops = <DayMapStop>[];
  for (final event in day.events) {
    for (final location in event.locationCards) {
      final name = (location['locationName'] as String? ?? '').trim();
      final lat = location['latitude'] as num?;
      final lng = location['longitude'] as num?;
      final url = Uri.tryParse(location['rawUrl'] as String? ?? '');
      final query = lat != null && lng != null
          ? '$lat,$lng'
          : name.isNotEmpty && name != 'Location'
              ? name
              : url?.queryParameters['query'] ??
                  url?.queryParameters['q'] ??
                  '';
      if (query.isNotEmpty && (stops.isEmpty || stops.last.query != query)) {
        stops.add(DayMapStop(name.isNotEmpty ? name : query, query));
      }
    }
  }
  return stops;
}

Uri dayMapUrl(List<DayMapStop> stops, String mode) {
  if (stops.isEmpty) throw ArgumentError('A map requires a location.');
  return Uri.https(
      'www.google.com', stops.length == 1 ? '/maps/search/' : '/maps/dir/', {
    'api': '1',
    if (stops.length == 1) 'query': stops.first.query,
    if (stops.length > 1) ...{
      'origin': stops.first.query,
      'destination': stops.last.query,
      'travelmode': mode,
      if (stops.length > 2)
        'waypoints':
            stops.sublist(1, stops.length - 1).map((s) => s.query).join('|'),
    },
  });
}
