import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/data/itinerary_database.dart';
import 'package:agent_desktop/ui/dashboard_screen.dart';
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
                end_date TEXT
              )
            ''');

            await db.insert('itineraries', {
              'title': 'Japan',
              'subtitle': 'Ancient temples, neon cities, and breathtaking cherry blossoms.',
              'duration': '6 Days',
              'date_range': 'Apr 12 - Apr 17, 2025',
              'image_path': 'assets/images/japan_clean.png',
            });

            await db.insert('itineraries', {
              'title': 'Switzerland',
              'subtitle': 'Breathtaking mountains, charming towns and unforgettable views.',
              'duration': '7 Days',
              'date_range': 'May 05 - May 12, 2025',
              'image_path': 'assets/images/switzerland_clean.png',
            });

            await db.insert('itineraries', {
              'title': 'Malaysia',
              'subtitle': 'Lush tropical rainforests, diverse cuisine, and iconic skylines.',
              'duration': '5 Days',
              'date_range': 'Jun 10 - Jun 15, 2025',
              'image_path': 'assets/images/malaysia_clean.png',
            });
          },
        ),
      );
      ItineraryDatabase.setDatabase(testDb);
    });

    tearDown(() async {
      await testDb.close();
      ItineraryDatabase.setDatabase(null);
    });

    test('Loads initial default itineraries from SQLite', () async {
      final items = await ItineraryDatabase.instance.getAllItineraries();
      expect(items.length, 3);
      expect(items.map((e) => e.title), containsAll(['Japan', 'Switzerland', 'Malaysia']));
    });

    test('Deletes itinerary and persists deletion in SQLite', () async {
      final itemsBefore = await ItineraryDatabase.instance.getAllItineraries();
      final japanItem = itemsBefore.firstWhere((e) => e.title == 'Japan');

      final rowsAffected = await ItineraryDatabase.instance.deleteItinerary(japanItem.id);
      expect(rowsAffected, 1);

      final itemsAfter = await ItineraryDatabase.instance.getAllItineraries();
      expect(itemsAfter.length, 2);
      expect(itemsAfter.any((e) => e.title == 'Japan'), isFalse);
    });

    test('Inserts new itinerary and persists in SQLite', () async {
      final newItem = await ItineraryDatabase.instance.insertItinerary(
        title: 'New York City',
        subtitle: 'The city that never sleeps.',
        duration: '4 Days',
        dateRange: 'Jul 20 - Jul 24, 2025',
        imagePath: 'assets/images/switzerland_clean.png',
      );

      expect(newItem.title, 'New York City');
      expect(newItem.id, isPositive);

      final allItems = await ItineraryDatabase.instance.getAllItineraries();
      expect(allItems.length, 4);
      expect(allItems.any((e) => e.title == 'New York City'), isTrue);
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

      // Verify all required fields are present
      expect(find.text('Create New Trip'), findsOneWidget);
      expect(find.text('Trip Banner'), findsOneWidget);
      expect(find.text('Upload from Folder'), findsOneWidget);
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
  });
}
