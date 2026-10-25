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
}
