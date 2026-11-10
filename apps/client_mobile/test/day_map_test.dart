import 'package:client_mobile/ui/day_map_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  test('uses every location in event order and encodes route mode and stops',
      () {
    ItineraryEvent event(String id, String name, {double? lat, double? lng}) =>
        ItineraryEvent(
            eventId: id,
            title: id,
            eventType: EventType.activity,
            startIso8601: '',
            endIso8601: '',
            timezoneIana: 'UTC',
            locationName: name,
            latitude: lat,
            longitude: lng);
    final day = ItineraryDay(
        dayNumber: 1,
        dateIso8601: '',
        title: '',
        primaryTimezoneIana: 'UTC',
        events: [
          event('1', 'Airport', lat: 33.99, lng: 74.77),
          event('2', 'Hotel & Spa'),
          event('3', 'Lake'),
          event('4', 'Hotel & Spa')
        ]);
    final stops = dayMapStops(day);
    expect(stops, hasLength(4));
    final url = dayMapUrl(stops, 'walking');
    expect(url.queryParameters['saddr'], '33.99,74.77');
    expect(url.queryParameters['daddr'], 'Hotel & Spa to:Lake to:Hotel & Spa');
    expect(url.queryParameters['dirflg'], 'w');
    final official = dayMapUrl(stops, 'bicycling', apiKey: 'test-key');
    expect(official.queryParameters['waypoints'], 'Hotel & Spa|Lake');
    expect(official.queryParameters['mode'], 'bicycling');
    expect(dayMapUrl(stops.take(1).toList(), 'driving').queryParameters['q'],
        '33.99,74.77');
    expect(dayMapStops(day.copyWith(events: [])), isEmpty);
  });
}
