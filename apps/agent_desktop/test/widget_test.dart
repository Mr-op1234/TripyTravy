import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/data/itinerary_database.dart';
import 'package:agent_desktop/ui/dashboard_screen.dart';
import 'package:agent_desktop/ui/trip_detail_screen.dart';
import 'package:agent_desktop/ui/widgets/smooth_scroll.dart';
import 'package:agent_desktop/ui/widgets/rich_description_editor.dart';
import 'package:agent_desktop/data/google_maps_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    ItineraryDatabase.initializeFfi();
  });

  group('ItineraryDatabase SQLite Tests', () {
    late Database testDb;

    setUp(() async {
      testDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE itineraries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                subtitle TEXT NOT NULL,
                duration TEXT NOT NULL,
                date_range TEXT NOT NULL,
                image_path TEXT NOT NULL,
                start_date TEXT,
                end_date TEXT,
                tagline TEXT,
                description TEXT
              )
            ''');

            await db.execute('''
              CREATE TABLE trip_events (
                id TEXT PRIMARY KEY,
                itinerary_id INTEGER NOT NULL,
                day_number INTEGER NOT NULL,
                title TEXT NOT NULL,
                event_date TEXT NOT NULL,
                start_time TEXT,
                end_time TEXT,
                duration TEXT NOT NULL,
                location TEXT NOT NULL,
                description TEXT,
                cover_image TEXT,
                photos_json TEXT,
                notes_json TEXT,
                sort_order INTEGER NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE trip_documents (
                id TEXT PRIMARY KEY,
                itinerary_id INTEGER NOT NULL,
                event_id TEXT,
                doc_type TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                file_name TEXT NOT NULL,
                file_size TEXT NOT NULL,
                file_path TEXT NOT NULL,
                color_scheme TEXT NOT NULL,
                location_name TEXT,
                latitude REAL,
                longitude REAL,
                map_url TEXT,
                attachments_json TEXT
              )
            ''');
          },
        ),
      );
      ItineraryDatabase.setDatabase(testDb);
    });

    tearDown(() async {
      await testDb.close();
      ItineraryDatabase.setDatabase(null);
    });

    test('Starts with empty database when no itineraries are added', () async {
      final items = await ItineraryDatabase.instance.getAllItineraries();
      expect(items, isEmpty);
    });

    test('Inserts new itinerary and persists in SQLite', () async {
      final newItem = await ItineraryDatabase.instance.insertItinerary(
        title: 'New York City',
        subtitle: 'The city that never sleeps.',
        duration: '4 Days',
        dateRange: 'Jul 20 - Jul 24, 2025',
        imagePath: '',
      );

      expect(newItem.title, 'New York City');
      expect(newItem.id, isPositive);

      final allItems = await ItineraryDatabase.instance.getAllItineraries();
      expect(allItems.length, 1);
      expect(allItems.first.title, 'New York City');
    });

    test('Inserts and retrieves events and documents for an itinerary', () async {
      final trip = await ItineraryDatabase.instance.insertItinerary(
        title: 'Switzerland & Italy',
        subtitle: 'Scenic railways and historic ruins.',
        duration: '30 Days',
        dateRange: '01-09-2030 -> 30-09-2030',
        imagePath: '',
      );

      final event = TripEventItem(
        id: 'evt_1',
        itineraryId: trip.id,
        title: 'Departure from CCU',
        eventDate: '2030-09-01',
        startTime: '04:15',
        endTime: '07:00',
        duration: '~ 2 hrs 45 mins',
        location: 'CCU',
        description: 'Flight check-in at gate 12.',
        notes: const ['Passport ready', 'Baggage drop'],
      );

      await ItineraryDatabase.instance.insertEvent(event);
      final events = await ItineraryDatabase.instance.getEventsForItinerary(trip.id);
      expect(events.length, 1);
      expect(events.first.title, 'Departure from CCU');
      expect(events.first.location, 'CCU');

      final doc = TripDocumentItem(
        id: 'doc_1',
        itineraryId: trip.id,
        eventId: 'evt_1',
        docType: 'flight',
        title: 'Boarding Pass CCU-DXB',
        fileName: 'boarding_pass.pdf',
        fileSize: '1.2 MB',
        filePath: 'test/path/boarding_pass.pdf',
      );

      await ItineraryDatabase.instance.insertDocument(doc);
      final docs = await ItineraryDatabase.instance.getDocumentsForItinerary(trip.id);
      expect(docs.length, 1);
      expect(docs.first.title, 'Boarding Pass CCU-DXB');
      expect(docs.first.docType, 'flight');
    });
  });

  group('Dashboard Widget Smoke Tests', () {
    testWidgets('Dashboard renders header, search bar, and itinerary cards', (WidgetTester tester) async {
      final sampleItems = [
        const DestinationItem(
          id: 1,
          title: 'Japan',
          subtitle: 'Ancient temples, neon cities, and breathtaking Mount Fuji.',
          duration: '6 Days',
          dateRange: 'Apr 12 - Apr 17, 2025',
          imagePath: 'assets/images/japan_clean.png',
        ),
        const DestinationItem(
          id: 2,
          title: 'Switzerland',
          subtitle: 'Breathtaking mountain peaks, charming alpine towns, and crystal lakes.',
          duration: '7 Days',
          dateRange: 'May 05 - May 12, 2025',
          imagePath: 'assets/images/switzerland_clean.png',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(initialDestinations: sampleItems),
        ),
      );
      await tester.pump();

      expect(find.text('Add More Trip'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
      expect(find.text('Switzerland'), findsOneWidget);
      expect(find.text('search Itinerary Name.'), findsOneWidget);

      // Verify three-dot options menu opens
      final moreButtons = find.byTooltip('Card Options');
      expect(moreButtons, findsWidgets);

      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Add More Trip opens dialog with Banner, Title, Description, and Dates', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(initialDestinations: []),
        ),
      );
      await tester.pump();

      // Tap + Add More Trip
      await tester.tap(find.text('Add More Trip'));
      await tester.pumpAndSettle();

      // Verify all required fields are present and banner is empty
      expect(find.text('Create New Trip'), findsOneWidget);
      expect(find.text('Trip Banner'), findsOneWidget);
      expect(find.text('No Banner Selected'), findsOneWidget);
      expect(find.text('Upload from Folder'), findsOneWidget);
      expect(find.text('Paste URL'), findsOneWidget);
      expect(find.text('Trip Title *'), findsOneWidget);
      expect(find.text('Trip Description'), findsOneWidget);
      expect(find.text('Start Date *'), findsOneWidget);
      expect(find.text('End Date *'), findsOneWidget);
      expect(find.text('Create Itinerary'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Trip'), findsNothing);
    });

    testWidgets('Edit button opens dialog with pre-filled options for Banner, Title, Description, and Dates', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleItems = [
        const DestinationItem(
          id: 1,
          title: 'Japan',
          subtitle: 'Ancient temples and neon cities.',
          duration: '6 Days',
          dateRange: 'Apr 12 - Apr 17, 2025',
          imagePath: 'assets/images/japan_clean.png',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(initialDestinations: sampleItems),
        ),
      );
      await tester.pump();

      // Open three-dot menu
      await tester.tap(find.byTooltip('Card Options').first);
      await tester.pumpAndSettle();

      // Click Edit
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Verify Edit dialog has all fields and pre-filled data
      expect(find.text('Edit Trip Itinerary'), findsOneWidget);
      expect(find.text('Trip Banner'), findsOneWidget);
      expect(find.text('Japan'), findsWidgets);
      expect(find.text('Trip Title *'), findsOneWidget);
      expect(find.text('Trip Description'), findsOneWidget);
      expect(find.text('Start Date *'), findsOneWidget);
      expect(find.text('End Date *'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Trip Itinerary'), findsNothing);
    });

    testWidgets('TripDetailScreen renders panoramic hero banner, badges, documents card, and itinerary section', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const sampleTrip = DestinationItem(
        id: 1,
        title: 'Switzerland & Italy',
        subtitle: 'No one knows what is going to happen in the future.',
        duration: '30 Days',
        dateRange: '01-09-2030 -> 30-09-2030',
        imagePath: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TripDetailScreen(
            item: sampleTrip,
            initialEvents: [],
            initialDocuments: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Banner
      expect(find.text('My Trips'), findsOneWidget);
      expect(find.text('Switzerland & Italy'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('01-09-2030 -> 30-09-2030'), findsOneWidget);
      expect(find.text('Change Banner'), findsOneWidget);
      expect(find.textContaining('Mobile Code'), findsNothing);
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);

      // Verify Documents trigger card
      expect(find.text('Information and documents'), findsOneWidget);

      // Verify SmoothScroll wrapper and desktop Scrollbar are present
      expect(find.byType(SmoothScroll), findsOneWidget);
      expect(find.byType(Scrollbar), findsOneWidget);

      // Verify Itinerary section
      expect(find.text('Itinerary'), findsOneWidget);
      expect(find.text('+ Add Event'), findsOneWidget);

      // Tap + Add Event and verify EventEditorDialog
      await tester.tap(find.text('+ Add Event'));
      await tester.pumpAndSettle();
      expect(find.text('Add Itinerary Event'), findsOneWidget);
      expect(find.text('Event Title *'), findsOneWidget);
      expect(find.text('Location / Venue'), findsOneWidget);

      // Close dialog via top-right close icon
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(find.text('Add Itinerary Event'), findsNothing);

      // Tap Information and documents trigger card
      await tester.tap(find.text('Information and documents'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Trip Documents & Information'), findsOneWidget);
      expect(find.text('+ Add Information'), findsOneWidget);

      // Tap + Add Information (Image 1 requirement)
      await tester.tap(find.text('+ Add Information'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify AddInformationDialog fields (as shown in user mockup)
      expect(find.text('Add Information'), findsOneWidget);
      expect(find.text('Title *'), findsOneWidget);
      expect(find.text('Description'), findsWidgets);
      expect(find.text('Attach Documents'), findsOneWidget);
      expect(find.text('Location Card (Google Maps)'), findsOneWidget);

      // Close AddInformationDialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Close DocumentsManagerDialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    test('GoogleMapsHelper parses place URLs and extracts coordinates and place name', () async {
      const url = 'https://www.google.com/maps/place/Matterhorn,+3920+Zermatt,+Switzerland/@45.9765664,7.6584514,15z';
      final result = await GoogleMapsHelper.parse(url);
      expect(result, isNotNull);
      expect(result!.locationName, 'Matterhorn, 3920 Zermatt, Switzerland');
      expect(result.latitude, closeTo(45.9765, 0.001));
      expect(result.longitude, closeTo(7.6584, 0.001));
      expect(result.coordinatesDisplay, contains('45.9766° N'));
    });

    testWidgets('SmoothScroll animates mouse wheel pointer scrolls smoothly', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: controller,
              child: SmoothScroll(
                controller: controller,
                child: Column(
                  children: List.generate(
                    50,
                    (index) => SizedBox(
                      height: 100,
                      child: Text('Item $index'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.offset, 0.0);

      // Dispatch a pointer scroll event (mouse wheel down 80px)
      final Offset center = tester.getCenter(find.byType(SingleChildScrollView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 80)));

      // Mid-animation frame: should be interpolating smoothly between 0 and 80
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.offset, greaterThan(0.0));
      expect(controller.offset, lessThan(80.0));

      // Settle animation to target
      await tester.pumpAndSettle();
      expect(controller.offset, closeTo(80.0, 1.0));
    });

    testWidgets('RichDescriptionEditor formats bold, lists, eraser, and handles undo/redo', (tester) async {
      final controller = TextEditingController(text: 'Swiss Flight');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify B, I, link, lists, and tools are rendered
      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.redo_rounded), findsOneWidget);
      expect(find.byIcon(Icons.crop_free_rounded), findsOneWidget);

      // Select text and click B (Bold)
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 12);
      await tester.tap(find.text('B'));
      await tester.pumpAndSettle();
      expect(controller.text, '**Swiss Flight**');

      // Click Undo
      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, 'Swiss Flight');

      // Click Redo
      await tester.tap(find.byIcon(Icons.redo_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, '**Swiss Flight**');

      // Click Clear Formatting (Eraser)
      await tester.tap(find.byTooltip('Clear Formatting'));
      await tester.pumpAndSettle();
      expect(controller.text, 'Swiss Flight');
    });
  });
}
