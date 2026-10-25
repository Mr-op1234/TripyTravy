import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import 'package:client_mobile/di/mobile_di_container.dart';
import 'package:client_mobile/ui/mobile_dashboard_screen.dart';
import 'package:client_mobile/ui/widgets/rounded_curved_arrow_painter.dart';

final class MockPlatformFile extends PlatformFile {
  @override
  final String name;
  final Uint8List _data;

  MockPlatformFile({required this.name, required List<int> bytes})
      : _data = Uint8List.fromList(bytes);

  @override
  Uri get uri => Uri.parse('file:///$name');

  @override
  XFile get xFile => XFile.fromData(_data, name: name);

  @override
  Future<Uint8List> readAsBytes() async => _data;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_data);

  @override
  Future<int?> length() async => _data.length;

  @override
  int? lengthSync() => _data.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MobileDiContainer testDi;

  setUp(() {
    testDi = MobileDiContainer(
      tripRepository: InMemoryTripRepositoryAdapter(),
    );
  });

  testWidgets(
      'Mobile Dashboard renders header, hamburger menu, and Inspiration demo trips',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: true,
        ),
      ),
    );

    // Initial pump & settle to allow async _initDashboard to load
    await tester.pumpAndSettle();

    // Verify Header
    expect(find.text('Tripy Travy'), findsOneWidget);
    expect(find.text('Your journeys across the World'), findsWidgets);
    expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

    // Verify Demo Trips (Osaka, Tokyo, Kyoto)
    expect(find.text('Osaka'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Kyoto'), findsOneWidget);

    // Verify Days count
    expect(find.text('4 Days'), findsNWidgets(2)); // Osaka and Kyoto
    expect(find.text('5 Days'), findsOneWidget); // Tokyo

    // Verify Date range formatted text
    expect(find.text('May 20, 2025 – May 23, 2025'), findsOneWidget);
    expect(find.text('May 24, 2025 – May 28, 2025'), findsOneWidget);
    expect(find.text('May 29, 2025 – Jun 1, 2025'), findsOneWidget);

    // Verify '+' button is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
      'When no trips are available, displays subtle "No trips, Import one" and rounded curved arrow',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: false, // Start empty
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify subtle themed minimalistic text
    expect(find.text('No trips, Import one'), findsOneWidget);

    // Verify rounded curved arrow CustomPaint is rendered
    final customPaintFinder = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter is RoundedCurvedArrowPainter,
    );
    expect(customPaintFinder, findsOneWidget);

    // Verify '+' button is still present and centered
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
      'Tapping "+" opens dialog with exact text "Select your Travel itinerary .tt file"',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap '+' action button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Verify pop-up dialog box opened
    expect(find.text('Import Itinerary'), findsOneWidget);

    // Verify exact required text
    expect(find.text('Select your Travel itinerary .tt file'), findsOneWidget);
    expect(find.text('Tap here to open file manager on your phone'),
        findsOneWidget);
  });

  testWidgets(
      'Tapping import area invokes file manager and imports new trip onto dashboard',
      (WidgetTester tester) async {
    bool filePickerInvoked = false;

    final sampleJson = jsonEncode({
      'tripId': 'trip_hokkaido',
      'title': 'Hokkaido',
      'subtitle': 'Winter wonderland',
      'destinationTags': ['Japan', 'Hokkaido'],
      'startDateIso8601': '2025-12-10',
      'endDateIso8601': '2025-12-16',
      'primaryTimezoneIana': 'Asia/Tokyo',
      'days': [],
    });

    final mockPlatformFile = MockPlatformFile(
      name: 'hokkaido_trip.tt',
      bytes: utf8.encode(sampleJson),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: false,
          filePickerOverride: () async {
            filePickerInvoked = true;
            return [mockPlatformFile];
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open import dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Tap on the designated "Select your Travel itinerary .tt file" area
    await tester.tap(find.text('Select your Travel itinerary .tt file'));
    await tester.pumpAndSettle();

    // Verify file picker callback was invoked
    expect(filePickerInvoked, isTrue);

    // Verify newly imported trip card appears immediately on the dashboard
    expect(find.text('Hokkaido'), findsOneWidget);
    expect(find.text('7 Days'), findsOneWidget);
  });

  testWidgets(
      'Trip card has three dots button with Mark as complete and Delete options',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Osaka, Tokyo, Kyoto are present
    expect(find.text('Osaka'), findsOneWidget);

    // Verify three-dot icons are present on cards
    final threeDotsFinder = find.byIcon(Icons.more_vert_rounded);
    expect(threeDotsFinder, findsWidgets);

    // Tap the first three-dot menu (Osaka)
    await tester.tap(threeDotsFinder.first);
    await tester.pumpAndSettle();

    // Verify popup menu options: Mark as complete and Delete
    expect(find.text('Mark as complete'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets(
      'Marking a trip as complete moves it from active list to completed section, accessible via bottom-right button and drawer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Osaka'), findsOneWidget);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Kyoto'), findsOneWidget);

    // When 0 completed trips exist, bottom-right completed button is cleanly hidden
    expect(find.byKey(const Key('completed_bottom_right_button')), findsNothing);

    // Tap three dots on the first card (Osaka)
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    // Tap "Mark as complete"
    await tester.tap(find.text('Mark as complete'));
    await tester.pumpAndSettle();

    // Osaka should now be moved out of active trips
    expect(find.text('Osaka'), findsNothing);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Kyoto'), findsOneWidget);

    // The bottom-right Completed button now appears with count badge '1'
    expect(find.byKey(const Key('completed_bottom_right_button')), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    // Tap the bottom-right completed button
    await tester.tap(find.byKey(const Key('completed_bottom_right_button')));
    await tester.pumpAndSettle();

    // Completed Trips screen is now displayed
    expect(find.text('Completed Trips'), findsOneWidget);
    expect(find.text('Osaka'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets); // Badge on the card

    // Tap the three dots on the completed Osaka card
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // In completed view, the option is "Mark as active"
    expect(find.text('Mark as active'), findsOneWidget);

    // Tap "Mark as active" to restore Osaka
    await tester.tap(find.text('Mark as active'));
    await tester.pumpAndSettle();

    // Completed view should now be empty
    expect(find.text('No Completed Trips Yet'), findsOneWidget);

    // Go back to main dashboard
    await tester.tap(find.byTooltip('Back to Dashboard'));
    await tester.pumpAndSettle();

    // Osaka should be back in active trips!
    expect(find.text('Osaka'), findsOneWidget);

    // And bottom-right completed button hides again because completed count is 0
    expect(find.byKey(const Key('completed_bottom_right_button')), findsNothing);
  });

  testWidgets(
      'Burger drawer contains Completed Trips tile and navigates to completed screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Drawer via hamburger button
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();

    // Verify Completed Trips tile is in drawer
    expect(find.byKey(const Key('drawer_completed_trips')), findsOneWidget);
    expect(find.text('Completed Trips'), findsOneWidget);

    // Tap Completed Trips in drawer
    await tester.tap(find.byKey(const Key('drawer_completed_trips')));
    await tester.pumpAndSettle();

    // Verify Completed Trips screen is displayed
    expect(find.text('Completed Trips'), findsOneWidget);
  });

  testWidgets(
      'Deleting a trip via card three-dot menu removes it after confirmation',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MobileDashboardScreen(
          di: testDi,
          autoSeedDemoTripsIfEmpty: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Osaka'), findsOneWidget);

    // Tap the three dots for Osaka
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog is visible
    expect(find.text('Delete Trip'), findsOneWidget);
    expect(find.text('Are you sure you want to permanently delete "Osaka"?'),
        findsOneWidget);

    // Confirm deletion
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify Osaka is permanently removed from dashboard
    expect(find.text('Osaka'), findsNothing);
    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text('Kyoto'), findsOneWidget);
  });
}

