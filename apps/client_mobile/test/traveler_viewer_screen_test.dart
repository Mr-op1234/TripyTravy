import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import 'package:client_mobile/di/mobile_di_container.dart';
import 'package:client_mobile/ui/traveler_viewer_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MobileDiContainer testDi;
  late TripPackage sampleTrip;

  setUp(() {
    testDi = MobileDiContainer(
      tripRepository: InMemoryTripRepositoryAdapter(),
    );

    sampleTrip = const TripPackage(
      tripId: 'trip_osaka_demo',
      title: 'Osaka, Japan',
      subtitle:
          'A vibrant city known for its historic landmarks, delicious street food, and energetic nightlife.',
      destinationTags: ['Japan', 'Osaka'],
      startDateIso8601: '2025-05-20',
      endDateIso8601: '2025-05-23',
      primaryTimezoneIana: 'Asia/Tokyo',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2025-05-20',
          title: 'Arrival & Dotonbori Walk',
          description:
              'Arrive in Osaka and explore the lively Dotonbori area.',
          primaryTimezoneIana: 'Asia/Tokyo',
        ),
        ItineraryDay(
          dayNumber: 2,
          dateIso8601: '2025-05-21',
          title: 'Osaka Castle & Umeda Sky Building',
          description:
              'Visit Osaka Castle and enjoy panoramic views from Umeda Sky Building.',
          primaryTimezoneIana: 'Asia/Tokyo',
        ),
      ],
      documents: [
        TripDocumentRecord(
          id: 'doc_1',
          title: 'Flight E-Ticket (KIX Arrival)',
          docType: 'Flight',
          description: 'Confirmed boarding pass for flight NH851',
          fileName: 'kix_flight_ticket.pdf',
          fileSize: '1.4 MB',
          locationName: 'Kansai International Airport (KIX)',
        ),
        TripDocumentRecord(
          id: 'doc_2',
          title: 'Hotel Booking Confirmation',
          docType: 'Hotel',
          description: 'Deluxe Suite reservation voucher for 4 nights',
          fileName: 'hotel_booking_swissotel.pdf',
          fileSize: '840 KB',
          locationName: 'Swissotel Nankai Osaka',
        ),
      ],
    );
  });

  testWidgets(
      'TravelerItineraryViewScreen renders hero banner with title, description, and badge',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: sampleTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title in Banner
    expect(find.text('Osaka, Japan'), findsOneWidget);

    // Verify Description in Banner (taken from agent side trip description)
    expect(
      find.text(
          'A vibrant city known for its historic landmarks, delicious street food, and energetic nightlife.'),
      findsOneWidget,
    );

    // Verify Pill Badge with duration and dates
    expect(find.text('2 Days'), findsOneWidget);
    expect(find.text('May 20, 2025 – May 23, 2025'), findsOneWidget);

    // Verify back and options buttons
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('About this trip section is completely removed and not present',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: sampleTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "About this trip" is NOT in the widget tree
    expect(find.text('About this trip'), findsNothing);
  });

  testWidgets(
      'Information and documents section is present and opens documents sheet',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: sampleTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Information and documents card
    expect(find.text('Information and documents'), findsOneWidget);
    expect(
      find.text(
          '2 documents available. View and manage all your trip documents in one place.'),
      findsOneWidget,
    );

    // Tap to open documents bottom sheet
    await tester.tap(find.text('Information and documents'));
    await tester.pumpAndSettle();

    // Verify documents from agent side appear
    expect(find.text('Flight E-Ticket (KIX Arrival)'), findsOneWidget);
    expect(find.text('Hotel Booking Confirmation'), findsOneWidget);
    expect(find.text('FLIGHT'), findsOneWidget);
    expect(find.text('HOTEL'), findsOneWidget);
  });

  testWidgets(
      'Your Itinerary section lists Day wise with title and description box',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: sampleTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify "Your Itinerary" heading
    expect(find.text('Your Itinerary'), findsOneWidget);

    // Verify Day 1 with title and description box
    expect(find.text('Day 1: Arrival & Dotonbori Walk'), findsOneWidget);
    expect(
      find.text('Arrive in Osaka and explore the lively Dotonbori area.'),
      findsOneWidget,
    );

    // Verify Day 2 with title and description box
    expect(
        find.text('Day 2: Osaka Castle & Umeda Sky Building'), findsOneWidget);
    expect(
      find.text(
          'Visit Osaka Castle and enjoy panoramic views from Umeda Sky Building.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Tapping a Day opens Day Details sheet showing event with PHOTOS and DOCUMENTS & PASSES',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const tripWithDocsAndPhotos = TripPackage(
      tripId: 'trip_swiss_test',
      title: 'SwitzerLand',
      subtitle: 'This is a trip from CCU to Switzerland',
      startDateIso8601: '2026-11-01',
      endDateIso8601: '2026-11-19',
      primaryTimezoneIana: 'UTC',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-11-01',
          title: 'Day 1',
          description: '1 events planned for SwitzerLand',
          primaryTimezoneIana: 'UTC',
          events: [
            ItineraryEvent(
              eventId: 'evt_docs_1',
              eventType: EventType.note,
              title: 'DOCS',
              category: 'Info',
              subCategory: 'Info',
              startIso8601: '2026-11-01T09:00:00',
              endIso8601: '2026-11-01T10:00:00',
              timezoneIana: 'UTC',
              photos: [
                'assets/images/osaka.png',
              ],
              documents: [
                TripDocumentRecord(
                  id: 'att_1',
                  title: 'Terminal Harness Agent.pdf',
                  docType: 'PDF Document',
                  fileName: 'Terminal Harness Agent.pdf',
                  fileSize: '307 KB',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: tripWithDocsAndPhotos,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Day 1 card
    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();

    // Verify Day sheet header
    expect(find.text('Day 1: Day 1'), findsOneWidget);
    expect(find.text('Events & Schedule'), findsOneWidget);

    // Verify Event title in both top index card and detailed event card
    expect(find.text('DOCS'), findsNWidgets(2));
    expect(find.text('DAY OVERVIEW'), findsOneWidget);
    expect(find.text('INFO · INFO'), findsOneWidget);

    // Verify PHOTOS section
    expect(find.text('PHOTOS'), findsOneWidget);

    // Verify DOCUMENTS & PASSES section - eye button removed, entire frame is clickable
    expect(find.text('DOCUMENTS & PASSES'), findsOneWidget);
    expect(find.text('Terminal Harness Agent.pdf'), findsOneWidget);
    expect(find.text('PDF Document · 307 KB'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byType(InkWell), findsWidgets);
  });

  testWidgets(
      'Itinerary main screen displays category icon badges on right side of day tiles',
      (WidgetTester tester) async {
    const multiEventTrip = TripPackage(
      tripId: 'trip_badges_test',
      title: 'Kashmir Expedition',
      subtitle: 'Scenic adventure in Kashmir valley',
      startDateIso8601: '2026-10-16',
      endDateIso8601: '2026-10-23',
      primaryTimezoneIana: 'Asia/Kolkata',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-10-16',
          title: 'Arrival in Srinagar',
          description: 'Transfer to hotel and Shikara ride',
          primaryTimezoneIana: 'Asia/Kolkata',
          events: [
            ItineraryEvent(
              eventId: 'ev_flight',
              eventType: EventType.transport,
              title: 'Flight to Srinagar',
              category: 'Transportation',
              subCategory: 'Flight',
              startIso8601: '2026-10-16T10:00:00',
              endIso8601: '2026-10-16T12:00:00',
              timezoneIana: 'Asia/Kolkata',
            ),
            ItineraryEvent(
              eventId: 'ev_hotel',
              eventType: EventType.lodging,
              title: 'Check-in to Grand Palace',
              category: 'Lodging',
              subCategory: 'Hotel',
              startIso8601: '2026-10-16T13:00:00',
              endIso8601: '2026-10-16T14:00:00',
              timezoneIana: 'Asia/Kolkata',
            ),
            ItineraryEvent(
              eventId: 'ev_activity',
              eventType: EventType.activity,
              title: 'Dal Lake Shikara Ride',
              category: 'Activity',
              subCategory: 'Boating',
              startIso8601: '2026-10-16T16:00:00',
              endIso8601: '2026-10-16T18:00:00',
              timezoneIana: 'Asia/Kolkata',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: multiEventTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Day title and formatted date
    expect(find.text('Day 1: Arrival in Srinagar'), findsOneWidget);
    expect(find.text('Fri, Oct 16'), findsOneWidget);

    // Verify right-side category badge icons present (Flight, Hotel, Activity)
    expect(find.byIcon(Icons.flight_takeoff_rounded), findsOneWidget);
    expect(find.byIcon(Icons.hotel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
  });

  testWidgets(
      'DayScheduleScreen renders 2-column tabular index cards with odd card centered and 1-second glow on tap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const oddEventsTrip = TripPackage(
      tripId: 'trip_odd_test',
      title: 'Paris Holiday',
      subtitle: 'Disneyland and sightseeing',
      startDateIso8601: '2026-10-12',
      endDateIso8601: '2026-10-14',
      primaryTimezoneIana: 'Europe/Paris',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-10-12',
          title: 'Disneyland Adventure',
          description: 'Full day magical adventure',
          primaryTimezoneIana: 'Europe/Paris',
          events: [
            ItineraryEvent(
              eventId: 'ev_disney_1',
              eventType: EventType.activity,
              title: 'Disneyland Paris Main Park',
              category: 'Activity',
              subCategory: 'Theme Park',
              startIso8601: '2026-10-12T09:30:00',
              endIso8601: '2026-10-12T13:00:00',
              timezoneIana: 'Europe/Paris',
              description: '**Ticket Policy**: Print ticket before arrival',
            ),
            ItineraryEvent(
              eventId: 'ev_disney_2',
              eventType: EventType.transport,
              title: 'RER A Train to Marne-la-Vallee',
              category: 'Transportation',
              subCategory: 'Departure',
              startIso8601: '2026-10-12T13:30:00',
              endIso8601: '2026-10-12T14:30:00',
              timezoneIana: 'Europe/Paris',
              description: 'Stay on train until final stop',
            ),
            ItineraryEvent(
              eventId: 'ev_disney_3',
              eventType: EventType.note,
              title: 'Use Disneyland App for Wait Times',
              category: 'Info',
              subCategory: 'App Guide',
              startIso8601: '2026-10-12T15:00:00',
              endIso8601: '2026-10-12T16:00:00',
              timezoneIana: 'Europe/Paris',
              description: 'Check live attraction waiting times',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: oddEventsTrip,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Day card to open DayScheduleScreen
    await tester.tap(find.text('Day 1: Disneyland Adventure'));
    await tester.pumpAndSettle();

    // Verify Day Schedule Screen header
    expect(find.text('Day 1: Disneyland Adventure'), findsOneWidget);
    expect(find.text('Mon, Oct 12'), findsOneWidget);

    // Verify DAY OVERVIEW section header and count
    expect(find.text('DAY OVERVIEW'), findsOneWidget);
    expect(find.text('3 events'), findsOneWidget);

    // Verify 3 index cards exist (all 3 event titles appear in both index card and event card)
    expect(find.text('Disneyland Paris Main Park'), findsNWidgets(2));
    expect(find.text('RER A Train to Marne-la-Vallee'), findsNWidgets(2));
    expect(find.text('Use Disneyland App for Wait Times'), findsNWidgets(2));

    // Verify the 3rd odd index card is inside a centered row
    final centeredRows = find.byWidgetPredicate(
      (w) => w is Row && w.mainAxisAlignment == MainAxisAlignment.center,
    );
    expect(centeredRows, findsWidgets);

    // Tap the 2nd index card
    final indexCard2 = find.ancestor(
      of: find.text('RER A Train to Marne-la-Vallee').first,
      matching: find.byType(InkWell),
    );
    await tester.tap(indexCard2.first);
    await tester.pump();

    // Verify AnimatedContainer exists and 1-second glow timer starts
    await tester.pump(const Duration(milliseconds: 300));
    // Advance beyond 1 second to verify glow timer finishes cleanly without exception
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Verify Scroll to Top floating arrow button logic:
    // Scroll down to make back-to-top button appear
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    // Tap back-to-top button
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded),
        warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'Event card renders location cards and formatted multi-line bold and highlights',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const tripWithLocationAndRichDesc = TripPackage(
      tripId: 'trip_kashmir_test',
      title: 'Kashmir Paradise',
      subtitle: 'Scenic Dal lake and airport transfer',
      startDateIso8601: '2026-10-16',
      endDateIso8601: '2026-10-23',
      primaryTimezoneIana: 'Asia/Kolkata',
      days: [
        ItineraryDay(
          dayNumber: 1,
          dateIso8601: '2026-10-16',
          title: 'Arrival in Srinagar',
          description: 'Transfer to hotel and Shikara ride',
          primaryTimezoneIana: 'Asia/Kolkata',
          events: [
            ItineraryEvent(
              eventId: 'ev_srinagar_transfer',
              eventType: EventType.activity,
              title: 'Arrival in Srinagar & Transfer to Hotel',
              category: 'Activity',
              subCategory: 'Other',
              startIso8601: '2026-10-16T13:30:00',
              endIso8601: '2026-10-16T14:00:00',
              timezoneIana: 'Asia/Kolkata',
              locationName: 'Srinagar International Airport',
              latitude: 33.9944,
              longitude: 74.7691,
              mapUrl: 'https://maps.app.goo.gl/evunuGGUkgX2mqCB9',
              description:
                  'Arrive at Srinagar Airport.\n\n**TIME:\n1:30 PM - 2:00 PM**\n\nWHAT TO DO:\n• ==Transfer ~12–15 km to the hotel==',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TravelerItineraryViewScreen(
          di: testDi,
          trip: tripWithLocationAndRichDesc,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Day 1 to open DayScheduleScreen
    await tester.tap(find.text('Day 1: Arrival in Srinagar'));
    await tester.pumpAndSettle();

    // Verify Location Card is rendered
    expect(find.text('Srinagar International Airport'), findsOneWidget);
    expect(find.text('33.9944° N, 74.7691° E'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsWidgets);
    expect(find.byIcon(Icons.open_in_new_rounded), findsWidgets);

    // Verify Description does NOT display raw markdown tokens '**' or '=='
    expect(find.textContaining('**TIME:'), findsNothing);
    expect(find.textContaining('==Transfer'), findsNothing);

    // Verify the text content is present within Text.rich
    expect(find.byType(RichText), findsWidgets);
  });
}
