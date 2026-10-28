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
}
