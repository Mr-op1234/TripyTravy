import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/data/itinerary_database.dart';
import 'package:agent_desktop/ui/dashboard_screen.dart';
import 'package:agent_desktop/ui/trip_detail_screen.dart';
import 'package:agent_desktop/ui/dialogs/documents_dialog.dart';
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
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
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
                sort_order INTEGER NOT NULL,
                FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE event_notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL,
                note_text TEXT NOT NULL,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE event_photos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL,
                photo_path TEXT NOT NULL,
                caption TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE CASCADE
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
                attachments_json TEXT,
                FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
                FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE SET NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE document_attachments (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                document_id TEXT NOT NULL,
                file_name TEXT NOT NULL,
                file_size TEXT NOT NULL,
                file_path TEXT NOT NULL,
                mime_type TEXT,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (document_id) REFERENCES trip_documents(id) ON DELETE CASCADE
              )
            ''');

            await db.execute('''
              CREATE TABLE trip_locations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                itinerary_id INTEGER NOT NULL,
                document_id TEXT,
                event_id TEXT,
                location_name TEXT NOT NULL,
                latitude REAL,
                longitude REAL,
                map_url TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (itinerary_id) REFERENCES itineraries(id) ON DELETE CASCADE,
                FOREIGN KEY (document_id) REFERENCES trip_documents(id) ON DELETE CASCADE,
                FOREIGN KEY (event_id) REFERENCES trip_events(id) ON DELETE SET NULL
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

    test('Enforces foreign key cascades across normalized multi-table database', () async {
      final trip = await ItineraryDatabase.instance.insertItinerary(
        title: 'Norway Expedition',
        subtitle: 'Fjords and Northern lights',
        duration: '10 Days',
        dateRange: 'Oct 01 - Oct 10, 2026',
        imagePath: '',
      );

      final event = TripEventItem(
        id: 'evt_norway_1',
        itineraryId: trip.id,
        title: 'Fjord Ferry Cruise',
        eventDate: '2026-10-02',
        duration: '3 hrs',
        location: 'Geiranger',
        notes: const ['Bring warm jacket', 'Camera battery full'],
        photos: const ['assets/images/fjord1.jpg'],
      );
      await ItineraryDatabase.instance.insertEvent(event);

      // Verify event_notes child table contains normalized 1NF rows
      final rawNotes = await testDb.query('event_notes', where: 'event_id = ?', whereArgs: ['evt_norway_1']);
      expect(rawNotes.length, 2);
      expect(rawNotes.first['note_text'], 'Bring warm jacket');

      // Verify event_photos child table contains normalized 1NF rows
      final rawPhotos = await testDb.query('event_photos', where: 'event_id = ?', whereArgs: ['evt_norway_1']);
      expect(rawPhotos.length, 1);
      expect(rawPhotos.first['photo_path'], 'assets/images/fjord1.jpg');

      // Insert normalized document with multiple attachments and location
      final doc = TripDocumentItem(
        id: 'doc_norway_pass',
        itineraryId: trip.id,
        eventId: 'evt_norway_1',
        docType: 'info',
        title: 'Passports',
        description: 'Keep passports safe.',
        fileName: 'passport1.pdf',
        fileSize: '5.3 MB',
        filePath: 'test/passport1.pdf',
        locationName: 'Geiranger Fjord Center',
        latitude: 62.1008,
        longitude: 7.2059,
        mapUrl: 'https://maps.google.com/?q=62.1008,7.2059',
        attachmentsJson: jsonEncode([
          {'name': 'passport1.pdf', 'size': '5.3 MB', 'path': 'test/passport1.pdf'},
          {'name': 'visa.pdf', 'size': '1.1 MB', 'path': 'test/visa.pdf'},
        ]),
      );
      await ItineraryDatabase.instance.insertDocument(doc);

      // Verify normalized document_attachments child table
      final rawAttachments = await testDb.query('document_attachments', where: 'document_id = ?', whereArgs: ['doc_norway_pass']);
      expect(rawAttachments.length, 2);
      expect(rawAttachments.first['file_name'], 'passport1.pdf');

      // Verify normalized trip_locations table
      final rawLocations = await testDb.query('trip_locations', where: 'document_id = ?', whereArgs: ['doc_norway_pass']);
      expect(rawLocations.length, 1);
      expect(rawLocations.first['location_name'], 'Geiranger Fjord Center');

      // Delete document -> verify document_attachments and trip_locations cascade delete
      await ItineraryDatabase.instance.deleteDocument('doc_norway_pass');
      final remainingAttachments = await testDb.query('document_attachments', where: 'document_id = ?', whereArgs: ['doc_norway_pass']);
      expect(remainingAttachments, isEmpty);
      final remainingLocations = await testDb.query('trip_locations', where: 'document_id = ?', whereArgs: ['doc_norway_pass']);
      expect(remainingLocations, isEmpty);

      // Delete entire itinerary -> verify cascading delete wipes events, notes, photos
      await ItineraryDatabase.instance.deleteItinerary(trip.id);
      final remainingEvents = await testDb.query('trip_events', where: 'itinerary_id = ?', whereArgs: [trip.id]);
      expect(remainingEvents, isEmpty);
      final remainingNotes = await testDb.query('event_notes', where: 'event_id = ?', whereArgs: ['evt_norway_1']);
      expect(remainingNotes, isEmpty);
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
      expect(find.widgetWithText(ElevatedButton, 'Add Information'), findsOneWidget);

      // Tap Add Information button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Information'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify AddInformationDialog fields (as shown in user mockup)
      expect(find.descendant(of: find.byType(AddInformationDialog), matching: find.text('Add Information')), findsOneWidget);
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

    testWidgets('DocumentsManagerDialog renders Image 1 card styling and vertical layout', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sampleDoc = TripDocumentItem(
        id: 'info_passports_1',
        itineraryId: 1,
        docType: 'info',
        title: 'Passports',
        description: 'These are your Passports Keep them safe.\n\nhere is link to the place: https://www.google.com/maps/search/?api=1&query=victoria+memorial',
        fileName: 'passport.pdf',
        fileSize: '5.3 MB',
        filePath: 'test/docs/passport.pdf',
        attachmentsJson: jsonEncode([
          {'name': 'passport.pdf', 'size': '5.3 MB', 'path': 'test/docs/passport.pdf'}
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocumentsManagerDialog(
              itineraryId: 1,
              tripTitle: 'Switzerland & Italy',
              initialDocuments: [sampleDoc],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dialog header
      expect(find.text('Trip Documents & Information'), findsOneWidget);

      // Verify Vertical format: ListView exists and no GridView
      expect(find.byType(ListView), findsWidgets);
      expect(find.byType(GridView), findsNothing);

      // Verify Image 1 card styling:
      // 1. Drag indicator
      expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);
      // 2. Circular info icon badge
      expect(find.byIcon(Icons.info_outline_rounded), findsWidgets);
      // 3. Uppercase title
      expect(find.text('PASSPORTS'), findsOneWidget);
      // 4. Edit button and 3-dots popup menu
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

      // 5. Rich description text with link
      expect(find.textContaining('These are your Passports Keep them safe.'), findsOneWidget);
      expect(find.textContaining('here is link to the place:'), findsOneWidget);
      expect(find.text('https://www.google.com/maps/search/?api=1&query=victoria+memorial'), findsOneWidget);

      // 6. Attachment pill with paperclip, bold name, friendly file type subtitle, and eye preview button
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
      expect(find.text('passport.pdf'), findsOneWidget);
      expect(find.text('PDF Document · 5.3 MB'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('AddInformationDialog supports editing pre-populated information card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final docToEdit = TripDocumentItem(
        id: 'info_hotel_1',
        itineraryId: 1,
        docType: 'info',
        title: 'Hotel Voucher',
        description: 'Check-in after 2 PM',
        fileName: 'voucher.pdf',
        fileSize: '1.2 MB',
        filePath: 'test/voucher.pdf',
        locationName: 'Grand Hotel',
        latitude: 46.2,
        longitude: 8.5,
        mapUrl: 'https://maps.google.com/?q=46.2,8.5',
        attachmentsJson: jsonEncode([
          {'name': 'voucher.pdf', 'size': '1.2 MB', 'path': 'test/voucher.pdf'}
        ]),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddInformationDialog(
              itineraryId: 1,
              itemToEdit: docToEdit,
              onDocumentSaved: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Edit header & Update button
      expect(find.text('Edit Information'), findsOneWidget);
      expect(find.text('Update Information'), findsOneWidget);

      // Verify pre-populated title and description
      expect(find.text('Hotel Voucher'), findsOneWidget);
      expect(find.text('Check-in after 2 PM'), findsOneWidget);
      expect(find.text('Grand Hotel'), findsOneWidget);
      expect(find.text('voucher.pdf (1.2 MB)'), findsOneWidget);
    });
  });
}
