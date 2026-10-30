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

    // Verify Event title and badge
    expect(find.text('DOCS'), findsOneWidget);
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
}
