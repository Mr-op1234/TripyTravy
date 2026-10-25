import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/data/itinerary_database.dart';
import 'package:agent_desktop/data/itinerary_file_manager.dart';
import 'package:agent_desktop/data/itinerary_tt_compiler.dart';
import 'package:agent_desktop/ui/dashboard_screen.dart';
import 'package:agent_desktop/ui/exported_itineraries_screen.dart';
import 'package:agent_desktop/ui/trip_detail_screen.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    ItineraryDatabase.initializeFfi();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tripytravy_export_test_');
    ItineraryFileManager.overrideBaseDirectory = tempDir;
  });

  tearDown(() async {
    ItineraryFileManager.overrideBaseDirectory = null;
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('ItineraryFileManager Tests', () {
    test('sanitizeName cleans illegal filesystem characters', () {
      expect(ItineraryFileManager.sanitizeName('Switzerland & Italy'), 'Switzerland & Italy');
      expect(ItineraryFileManager.sanitizeName('Vietnam: Special *Trip?'), 'Vietnam_ Special _Trip_');
      expect(ItineraryFileManager.sanitizeName('Malaysia / Kuala Lumpur'), 'Malaysia _ Kuala Lumpur');
      expect(ItineraryFileManager.sanitizeName('   '), 'Untitled_Itinerary');
    });

    test('generateTtFileName generates <itinerary-name-Date-time-stamp>.tt format', () {
      final dt = DateTime(2026, 10, 25, 19, 45, 30);
      final filename = ItineraryFileManager.generateTtFileName('Vietnam', dt);
      expect(filename, 'Vietnam-2026-10-25-194530.tt');

      final complexFilename = ItineraryFileManager.generateTtFileName('Switzerland & Italy', dt);
      expect(complexFilename, 'Switzerland & Italy-2026-10-25-194530.tt');
    });

    test('ensureDefaultFolders creates folders for Switzerland & Italy, Vietnam, Malaysia', () async {
      await ItineraryFileManager.ensureDefaultFolders();

      final base = await ItineraryFileManager.getBaseDirectory();
      expect(await Directory('${base.path}/Switzerland & Italy').exists(), isTrue);
      expect(await Directory('${base.path}/Vietnam').exists(), isTrue);
      expect(await Directory('${base.path}/Malaysia').exists(), isTrue);
    });

    test('saveTtFile and getExportedTtFiles manages .tt containers in itinerary folder', () async {
      final fakeBytes = [0x54, 0x54, 0x52, 0x56, 0x01, 0x02, 0x03];
      final savedFile = await ItineraryFileManager.saveTtFile(
        itineraryTitle: 'Vietnam',
        bytes: fakeBytes,
        customFileName: 'Vietnam-2026-10-25-194530.tt',
      );

      expect(await savedFile.exists(), isTrue);
      expect(savedFile.path.endsWith('Vietnam-2026-10-25-194530.tt'), isTrue);

      final files = await ItineraryFileManager.getExportedTtFiles('Vietnam');
      expect(files.length, 1);
      expect(files.first.path, savedFile.path);
    });
  });

  group('ItineraryTtCompiler Tests', () {
    test('Compiles DestinationItem with days and events into encrypted TTRV v1 container', () async {
      const destination = DestinationItem(
        id: 101,
        title: 'Vietnam',
        subtitle: 'Good Trips, Brighter Stories',
        duration: '10 Days',
        dateRange: 'Nov 1 - 10, 2026',
        imagePath: 'assets/vietnam.jpg',
        startDate: '2026-11-01',
        endDate: '2026-11-10',
        tagline: 'EXPLORE • DISCOVER • EXPERIENCE',
        description: 'Custom travel itinerary across Vietnam.',
      );

      final days = [
        const TripDayItem(
          id: 'day_101_1',
          itineraryId: 101,
          dayNumber: 1,
          title: 'Day 1 - Arrival in Da Nang',
          date: '2026-11-01',
        ),
      ];

      final events = [
        const TripEventItem(
          id: 'evt_101_1',
          itineraryId: 101,
          dayId: 'day_101_1',
          dayNumber: 1,
          title: 'Golden Bridge Ba Na Hills',
          eventDate: '2026-11-01',
          startTime: '09:00',
          endTime: '12:00',
          duration: '3 hrs',
          location: 'Da Nang, Vietnam',
          category: 'Activity',
        ),
      ];

      final compiledBytes = await ItineraryTtCompiler.compile(
        trip: destination,
        days: days,
        events: events,
        documents: [],
      );

      // Verify TTRV v1 magic header: 'T', 'T', 'R', 'V'
      expect(compiledBytes.length, greaterThan(56));
      expect(compiledBytes[0], 0x54);
      expect(compiledBytes[1], 0x54);
      expect(compiledBytes[2], 0x52);
      expect(compiledBytes[3], 0x56);

      // Verify unpackability via core TtrvContainerCipherAdapter & ProtobufTripMapper
      const cipher = TtrvContainerCipherAdapter();
      final unpacked = await cipher.unpackContainer(containerBytes: compiledBytes);
      expect(unpacked.protobufBytes, isNotEmpty);

      const mapper = ProtobufTripMapper();
      final restoredTrip = mapper.fromWireBytes(unpacked.protobufBytes);
      expect(restoredTrip.title, 'Vietnam');
      expect(restoredTrip.subtitle, 'Custom travel itinerary across Vietnam.');
      expect(restoredTrip.days.length, 1);
      expect(restoredTrip.days.first.title, 'Day 1 - Arrival in Da Nang');
      expect(restoredTrip.days.first.events.length, 1);
      expect(restoredTrip.days.first.events.first.title, 'Golden Bridge Ba Na Hills');
    });
  });

  group('DashboardScreen Drawer & Hamburger Navigation Tests', () {
    testWidgets('Dashboard renders hamburger icon, shifted logo, and opens drawer with Exported itineraries',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const sampleDestinations = [
        DestinationItem(
          id: 1,
          title: 'Switzerland & Italy',
          subtitle: 'Alpine scenic routes',
          duration: '30 Days',
          dateRange: '01-09-2030 -> 30-09-2030',
          imagePath: '',
        ),
        DestinationItem(
          id: 2,
          title: 'Vietnam',
          subtitle: 'Good Trips, Brighter Stories',
          duration: '10 Days',
          dateRange: 'Nov 1 - 10, 2026',
          imagePath: '',
        ),
        DestinationItem(
          id: 3,
          title: 'Malaysia',
          subtitle: 'Kuala Lumpur and Penang',
          duration: '7 Days',
          dateRange: 'Dec 1 - 7, 2026',
          imagePath: '',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: DashboardScreen(
            initialDestinations: sampleDestinations,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Hamburger Icon is present
      final hamburgerFinder = find.byKey(const Key('dashboard_hamburger_button'));
      expect(hamburgerFinder, findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // 2. Click Hamburger Icon to open drawer
      await tester.tap(hamburgerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 3. Verify Drawer opened and has "Exported itineraries" option
      expect(find.byType(Drawer), findsOneWidget);
      expect(find.text('TripyTravy'), findsOneWidget);
      expect(find.text('Agent Workspace'), findsOneWidget);
      final exportedOptionFinder = find.byKey(const Key('drawer_exported_itineraries_option'));
      expect(exportedOptionFinder, findsOneWidget);
      expect(find.text('Exported itineraries'), findsOneWidget);

      // 4. Click "Exported itineraries" to navigate to ExportedItinerariesScreen
      await tester.tap(exportedOptionFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Verify navigation to the new page (not a popup dialog, no trip cards)
      expect(find.byType(ExportedItinerariesScreen), findsOneWidget);
      expect(find.text('Exported Itineraries'), findsOneWidget);
      expect(find.text('Back to Dashboard'), findsOneWidget);

      // Verify table header format |No.|Itinerary Name|Exported itinerary|
      expect(find.text('No.'), findsOneWidget);
      expect(find.text('Itinerary Name'), findsOneWidget);
      expect(find.text('Exported itinerary'), findsOneWidget);

      // Verify listings for Switzerland & Italy, Vietnam, Malaysia
      expect(find.text('Switzerland & Italy'), findsOneWidget);
      expect(find.text('Vietnam'), findsOneWidget);
      expect(find.text('Malaysia'), findsOneWidget);

      // Click "Back to Dashboard" and return
      await tester.tap(find.text('Back to Dashboard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ExportedItinerariesScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });
  });

  group('ExportedItinerariesScreen Table Tests', () {
    testWidgets('Renders table with No., Itinerary Name, Exported itinerary and clickable listings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create a mock exported .tt file for Vietnam
      await ItineraryFileManager.saveTtFile(
        itineraryTitle: 'Vietnam',
        bytes: [0x54, 0x54, 0x52, 0x56, 0x01, 0x02],
        customFileName: 'Vietnam-2026-10-25-194530.tt',
      );

      const items = [
        DestinationItem(
          id: 1,
          title: 'Switzerland & Italy',
          subtitle: '',
          duration: '30 Days',
          dateRange: '',
          imagePath: '',
        ),
        DestinationItem(
          id: 2,
          title: 'Vietnam',
          subtitle: '',
          duration: '10 Days',
          dateRange: '',
          imagePath: '',
        ),
        DestinationItem(
          id: 3,
          title: 'Malaysia',
          subtitle: '',
          duration: '7 Days',
          dateRange: '',
          imagePath: '',
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: ExportedItinerariesScreen(
            initialItineraries: items,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check Table headers
      expect(find.text('No.'), findsOneWidget);
      expect(find.text('Itinerary Name'), findsOneWidget);
      expect(find.text('Exported itinerary'), findsOneWidget);

      // Check numbers
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);

      // Check Vietnam exported .tt listing
      expect(find.text('Vietnam-2026-10-25-194530.tt'), findsOneWidget);

      // Check empty listing for Switzerland & Italy
      expect(find.textContaining('No .tt files exported yet'), findsWidgets);

      // Tap on the Vietnam .tt file listing chip
      await tester.tap(find.text('Vietnam-2026-10-25-194530.tt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('TripDetailScreen Three-Dot Menu Options Tests', () {
    testWidgets('Three dots menu has "Export to .tt file" and does NOT have "Change Banner"',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool savePickerCalled = false;
      bool explorerOpened = false;

      TripDetailScreen.saveFilePickerOverride = ({
        required String fileName,
        required Uint8List bytes,
        String? dialogTitle,
        String? initialDirectory,
        FileType? type,
        List<String>? allowedExtensions,
      }) async {
        savePickerCalled = true;
        return Uri.file('${tempDir.path}/Vietnam/$fileName');
      };

      ItineraryFileManager.openExplorerOverride = (path) async {
        explorerOpened = true;
      };

      addTearDown(() {
        TripDetailScreen.saveFilePickerOverride = null;
        ItineraryFileManager.openExplorerOverride = null;
      });

      const sampleTrip = DestinationItem(
        id: 2,
        title: 'Vietnam',
        subtitle: 'Good Trips, Brighter Stories',
        duration: '10 Days',
        dateRange: 'Nov 1 - 10, 2026',
        imagePath: '',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TripDetailScreen(
            item: sampleTrip,
            initialDays: [],
            initialEvents: [],
            initialDocuments: [],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Outside "Change Banner" button is present
      expect(find.text('Change Banner'), findsOneWidget);

      // 2. Open Three-Dots popup menu
      final threeDotsFinder = find.byTooltip('Itinerary Options');
      expect(threeDotsFinder, findsOneWidget);
      await tester.tap(threeDotsFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Inside popup menu:
      // "Change Banner" should NOT be in the popup menu items
      // (The only "Change Banner" text in the whole tree is the button outside)
      expect(find.text('Change Banner'), findsOneWidget);

      // 4. "Export to .tt file" MUST be in the popup menu!
      expect(find.text('Export to .tt file'), findsOneWidget);

      // 5. Tap "Export to .tt file"
      await tester.tap(find.text('Export to .tt file'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify exporting progress and overrides called
      expect(savePickerCalled, isTrue);
      expect(explorerOpened, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
