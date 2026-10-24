import 'package:test/test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  test('flattens events chronologically and resolves active/upcoming events',
      () {
    const flight = ItineraryEvent(
      eventId: 'ev_flight_1',
      title: 'Flight to Singapore',
      eventType: EventType.flight,
      startIso8601: '2026-11-01T08:00:00Z',
      endIso8601: '2026-11-01T12:00:00Z',
      timezoneIana: 'Asia/Singapore',
      flight: FlightDetails(
        airlineName: 'Singapore Airlines',
        flightNumber: 'SQ402',
        departureIata: 'DEL',
        arrivalIata: 'SIN',
        departureTimezoneIana: 'Asia/Kolkata',
        arrivalTimezoneIana: 'Asia/Singapore',
        seatNumber: '14A',
      ),
    );

    const hotel = ItineraryEvent(
      eventId: 'ev_hotel_1',
      title: 'Marina Bay Sands Check-In',
      eventType: EventType.lodging,
      startIso8601: '2026-11-01T14:00:00Z',
      endIso8601: '2026-11-01T15:00:00Z',
      timezoneIana: 'Asia/Singapore',
      lodging: LodgingDetails(
        propertyName: 'Marina Bay Sands',
        address: '10 Bayfront Ave, Singapore',
      ),
    );

    const dinner = ItineraryEvent(
      eventId: 'ev_dinner_1',
      title: 'Gardens by the Bay Dinner',
      eventType: EventType.meal,
      startIso8601: '2026-11-01T19:00:00Z',
      endIso8601: '2026-11-01T21:00:00Z',
      timezoneIana: 'Asia/Singapore',
      meal: MealDetails(
        restaurantName: 'Satay by the Bay',
        address: 'Gardens by the Bay',
      ),
    );

    const trip = TripPackage(
      tripId: 'trip_singapore',
      title: 'Singapore City Explorer',
      startDateIso8601: '2026-11-01',
      endDateIso8601: '2026-11-05',
      primaryTimezoneIana: 'Asia/Singapore',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-11-01',
          title: 'Arrival in Singapore',
          primaryTimezoneIana: 'Asia/Singapore',
          events: [dinner, flight, hotel], // Deliberately out of order
        ),
      ],
    );

    final timeline = TravelerTimelineService(trip: trip);

    // 1. Chronological sorting check
    final events = timeline.getAllEventsChronological();
    expect(events.length, 3);
    expect(events[0].event.eventId, 'ev_flight_1');
    expect(events[1].event.eventId, 'ev_hotel_1');
    expect(events[2].event.eventId, 'ev_dinner_1');

    // 2. Flight / Lodging categorization
    expect(timeline.getTransportationLegs().length, 1);
    expect(timeline.getLodgingStays().length, 1);

    // 3. Current active event during the flight (10:00 AM UTC)
    final duringFlight = DateTime.parse('2026-11-01T10:00:00Z');
    final activeEvent = timeline.getCurrentEvent(now: duringFlight);
    expect(activeEvent, isNotNull);
    expect(activeEvent!.event.eventId, 'ev_flight_1');

    // 4. Next upcoming event right after flight (12:30 PM UTC)
    final postFlight = DateTime.parse('2026-11-01T12:30:00Z');
    final nextEvent = timeline.getNextUpcomingEvent(now: postFlight);
    expect(nextEvent, isNotNull);
    expect(nextEvent!.event.eventId, 'ev_hotel_1');

    // Countdown until 14:00 hotel check-in
    final countdown = timeline.getTimeUntilNextEvent(now: postFlight);
    expect(countdown, isNotNull);
    expect(countdown!.inMinutes, 90); // 1.5 hours
  });
}
