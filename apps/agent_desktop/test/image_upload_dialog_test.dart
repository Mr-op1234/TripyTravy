import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/ui/dialogs/image_upload_dialog.dart';
import 'package:agent_desktop/ui/dialogs/day_detail_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      (MethodCall call) async {
        if (call.method == 'image') return null;
        if (call.method == 'files') return <String>[];
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('pasteboard'),
      null,
    );
  });

  group('ImageUploadDialog Tests', () {
    test('ImageUploadDialog supports standard images and GIFs', () {
      final exts = ImageUploadDialog.supportedExtensions;
      expect(exts, contains('png'));
      expect(exts, contains('jpg'));
      expect(exts, contains('jpeg'));
      expect(exts, contains('webp'));
      expect(exts, contains('gif'));
      expect(exts, contains('bmp'));
      expect(exts, contains('heic'));
    });

    testWidgets('renders upload dialog with exact requested text and controls',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageUploadDialog(
              onImageAdded: (_) {},
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('Upload Images & GIFs'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify required prompt text
      expect(
        find.text('Click to open folder to upload images or directly paste here'),
        findsOneWidget,
      );

      // Verify subtext and Ctrl+V indicator
      expect(
        find.text('PNG, JPG, JPEG, WEBP, GIF • Press Ctrl + V to paste'),
        findsOneWidget,
      );
      expect(find.text('Ctrl + V enabled'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Ctrl + V with empty clipboard shows helpful status feedback',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dialogKey = GlobalKey<ImageUploadDialogState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageUploadDialog(
              key: dialogKey,
              onImageAdded: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Trigger clipboard paste
      await dialogKey.currentState!.pasteFromClipboard();
      await tester.pump();

      // Verify status feedback message
      expect(
        find.text('No image or GIF found in clipboard to paste'),
        findsOneWidget,
      );
    });

    testWidgets('renders preview list when photos are provided',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageUploadDialog(
              currentPhotos: const ['assets/images/banner1.png'],
              onImageAdded: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ImageUploadDialog), findsOneWidget);
    });

    testWidgets(
        'AddEventDialog button opens ImageUploadDialog with expected text',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddEventDialog(
              itineraryId: 1,
              dayId: 'day-1',
              dayNumber: 1,
              onEventSaved: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure ImageUploadDialog is not open initially
      expect(find.byType(ImageUploadDialog), findsNothing);

      // Verify button exists
      final addImagesButton = find.widgetWithText(
        OutlinedButton,
        'Add Images (PNG, JPG, WEBP, GIF)',
      );
      expect(addImagesButton, findsOneWidget);

      // Tap Add Images button
      await tester.tap(addImagesButton);
      await tester.pumpAndSettle();

      // ImageUploadDialog must now be open
      expect(find.byType(ImageUploadDialog), findsOneWidget);
      expect(
        find.text('Click to open folder to upload images or directly paste here'),
        findsOneWidget,
      );

      // Tap Close button to dismiss
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // ImageUploadDialog must be dismissed
      expect(find.byType(ImageUploadDialog), findsNothing);
    });
  });
}
