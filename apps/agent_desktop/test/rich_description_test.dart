import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/ui/widgets/rich_description_editor.dart';
import 'package:agent_desktop/ui/dialogs/day_detail_dialog.dart';

void main() {
  group('RichDescriptionSyntax & Editor Tests', () {
    test(
        'RichTextEditingController parses formatted text into pure clean text without raw delimiters',
        () {
      const text =
          'Here is <b>bold</b>, <i>italic</i>, <mark>highlight</mark>, and [link text](https://example.com) with **markdown bold** and ==yellow==.';
      final controller = RichTextEditingController(text: text);
      final span = controller.buildTextSpan(
        context: null as dynamic,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        withComposing: false,
      );

      const expectedCleanText =
          'Here is bold, italic, highlight, and link text with markdown bold and yellow.';
      expect(controller.text, equals(expectedCleanText));
      expect(span.toPlainText(includePlaceholders: false),
          equals(expectedCleanText));
    });

    test(
        'RichDescriptionSyntax identifies bold, italic, highlight, underline, and link styles',
        () {
      const text =
          'Alpha **bold text** Beta <mark>highlighted</mark> Gamma <u>underlined</u> Delta [link label](https://test.com)';
      final controller = RichTextEditingController(text: text);
      final span = controller.buildTextSpan(
        context: null as dynamic,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        withComposing: false,
      );

      const expectedClean =
          'Alpha bold text Beta highlighted Gamma underlined Delta link label';
      expect(span.toPlainText(), equals(expectedClean));
      final children = span.children!;
      expect(children.isNotEmpty, isTrue);

      bool foundBold = false;
      bool foundHighlight = false;
      bool foundUnderline = false;
      bool foundLink = false;

      for (final s in children) {
        if (s is TextSpan) {
          if (s.text == 'bold text' && s.style?.fontWeight == FontWeight.bold) {
            foundBold = true;
          }
          if (s.text == 'highlighted' &&
              s.style?.backgroundColor == const Color(0xFFFEF08A)) {
            foundHighlight = true;
          }
          if (s.text == 'underlined' &&
              s.style?.decoration == TextDecoration.underline) {
            foundUnderline = true;
          }
          if (s.text == 'link label' &&
              s.style?.color == const Color(0xFF2563EB)) {
            foundLink = true;
          }
        }
      }

      expect(foundBold, isTrue, reason: 'Bold text should have FontWeight.bold');
      expect(foundHighlight, isTrue,
          reason: 'Highlight text should have yellow background Color(0xFFFEF08A)');
      expect(foundUnderline, isTrue,
          reason: 'Underline text should have TextDecoration.underline');
      expect(foundLink, isTrue, reason: 'Link text should have blue color Color(0xFF2563EB)');
    });

    test(
        'sanitizeDescription converts XML tags to clean markdown and removes XML marks',
        () {
      const xmlInput =
          '<center><b>Important Trip</b></center>\n<mark>Must visit</mark> and <i>pack well</i>. <unknown>text</unknown>';
      final sanitized = sanitizeDescription(xmlInput);

      // Verify complete elimination of XML tags
      expect(sanitized.contains('<center>'), isFalse);
      expect(sanitized.contains('</center>'), isFalse);
      expect(sanitized.contains('<b>'), isFalse);
      expect(sanitized.contains('</b>'), isFalse);
      expect(sanitized.contains('<mark>'), isFalse);
      expect(sanitized.contains('</mark>'), isFalse);
      expect(sanitized.contains('<i>'), isFalse);
      expect(sanitized.contains('</i>'), isFalse);
      expect(sanitized.contains('<unknown>'), isFalse);

      // Markdown equivalents
      expect(sanitized, contains('**Important Trip**'));
      expect(sanitized, contains('==Must visit=='));
      expect(sanitized, contains('*pack well*'));
    });

    test('EditableTableData handles additions, removals, and markdown conversion',
        () {
      final table = EditableTableData.defaultTable(2, 2);
      expect(table.headers.length, 2);
      expect(table.rows.length, 2);

      table.addRow();
      expect(table.rows.length, 3);
      table.removeRow();
      expect(table.rows.length, 2);

      table.addColumn();
      expect(table.headers.length, 3);
      table.removeColumn();
      expect(table.headers.length, 2);

      final md = table.toMarkdown();
      expect(md.startsWith('| Header 1 | Header 2 |'), isTrue);

      final parsed = EditableTableData.parseFromMarkdown(md);
      expect(parsed, isNotNull);
      expect(parsed!.headers.length, 2);
      expect(parsed.rows.length, 2);
    });

    test('extractTableAndText cleanly separates table and paragraphs', () {
      const input =
          'Pre-table note.\n\n| H1 | H2 |\n| :--- | :--- |\n| C1 | C2 |\n\nPost-table note.';
      final extracted = extractTableAndText(input);
      expect(extracted.table, isNotNull);
      expect(extracted.table!.headers, ['H1', 'H2']);
      expect(extracted.textWithoutTable, contains('Pre-table note.'));
      expect(extracted.textWithoutTable, contains('Post-table note.'));
      expect(extracted.textWithoutTable.contains('| H1 | H2 |'), isFalse);
    });

    testWidgets(
        'RichDescriptionView strips tags and renders formatted spans without literal XML',
        (tester) async {
      const rawText =
          'Welcome to <mark>Zurich</mark>! See <b>Lake Zurich</b> or visit [Official Site](https://zuerich.com).';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionView(description: rawText),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Literal XML/markdown tags MUST NOT be visible
      expect(find.textContaining('<mark>'), findsNothing);
      expect(find.textContaining('</mark>'), findsNothing);
      expect(find.textContaining('<b>'), findsNothing);
      expect(find.textContaining('</b>'), findsNothing);
      expect(find.textContaining('[Official Site]('), findsNothing);

      // Clean text must be visible
      expect(find.textContaining('Zurich'), findsWidgets);
      expect(find.textContaining('Lake Zurich'), findsWidgets);
      expect(find.textContaining('Official Site'), findsWidgets);
    });

    testWidgets(
        'RichDescriptionView renders markdown table as a visual Table widget',
        (tester) async {
      const tableText = '''
Trip Schedule:
| Day | Activity | Location |
| :--- | :--- | :--- |
| Day 1 | Arrival & Check-in | Zurich Hotel |
| Day 2 | Alpine Excursion | Mount Titlis |
''';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionView(description: tableText),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find a Table widget
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('Arrival & Check-in'), findsOneWidget);
      expect(find.text('Mount Titlis'), findsOneWidget);
    });

    testWidgets(
        'RichDescriptionEditor inserts and manages interactive table visually',
        (tester) async {
      final controller = TextEditingController(text: 'Itinerary details');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Table tool button
      await tester.tap(find.byTooltip('Insert Table'));
      await tester.pumpAndSettle();

      // Interactive table card should now exist
      expect(find.text('Table'), findsOneWidget);
      expect(find.text('+ Row'), findsOneWidget);
      expect(find.text('+ Col'), findsOneWidget);

      // Tap + Row
      await tester.tap(find.text('+ Row'));
      await tester.pumpAndSettle();
      expect(find.text('3 rows × 3 cols'), findsOneWidget);

      // Tap + Col
      await tester.tap(find.text('+ Col'));
      await tester.pumpAndSettle();
      expect(find.text('3 rows × 4 cols'), findsOneWidget);

      // Tap Delete Table
      await tester.tap(find.byTooltip('Delete Table'));
      await tester.pumpAndSettle();
      expect(find.text('Table'), findsNothing);
    });

    testWidgets('RichDescriptionEditor handles bullet and numbered lists',
        (tester) async {
      final controller = TextEditingController(text: 'Item 1\nItem 2');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select all and toggle bullet list
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 13);
      await tester.tap(find.byIcon(Icons.format_list_bulleted_rounded));
      await tester.pumpAndSettle();

      expect(controller.text, '• Item 1\n• Item 2');

      // Toggle numbered list
      controller.selection =
          TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      await tester.tap(find.byIcon(Icons.format_list_numbered_rounded));
      await tester.pumpAndSettle();

      expect(controller.text, '1. Item 1\n2. Item 2');
    });

    testWidgets('RichDescriptionEditor handles Underline and all 4 alignment controls',
        (tester) async {
      final controller = TextEditingController(text: 'Centered Headline');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RichDescriptionEditor(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap align center
      await tester.tap(find.byIcon(Icons.format_align_center_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, contains('<!-- align:center -->'));

      // Tap align right
      await tester.tap(find.byIcon(Icons.format_align_right_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, contains('<!-- align:right -->'));

      // Tap justify
      await tester.tap(find.byIcon(Icons.format_align_justify_rounded));
      await tester.pumpAndSettle();
      expect(controller.text, contains('<!-- align:justify -->'));

      // Tap align left
      await tester.tap(find.byIcon(Icons.format_align_left_rounded));
      await tester.pumpAndSettle();
      expect(controller.text.contains('<!-- align:'), isFalse);

      // Select all and click Underline
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 17);
      await tester.tap(find.text('U'));
      await tester.pumpAndSettle();
      expect(controller.text, contains('<u>Centered Headline</u>'));
    });

    test('HighlightColor enum properties and styles', () {
      expect(HighlightColor.yellow.bg, equals(const Color(0xFFFEF08A)));
      expect(HighlightColor.yellow.fg, equals(const Color(0xFF854D0E)));
      expect(HighlightColor.yellow.id, equals('yellow'));

      expect(HighlightColor.lightRed.bg, equals(const Color(0xFFFECACA)));
      expect(HighlightColor.lightRed.fg, equals(const Color(0xFF991B1B)));
      expect(HighlightColor.lightRed.id, equals('red'));

      expect(HighlightColor.navyBlue.bg, equals(const Color(0xFF1E3A8A)));
      expect(HighlightColor.navyBlue.fg, equals(const Color(0xFFFFFFFF)));
      expect(HighlightColor.navyBlue.id, equals('navy'));
    });

    test('RichTextEditingController correctly parses and serializes multiple highlight colors', () {
      const input = 'Standard ==yellow note== and ==red:urgent alert== plus ==navy:info pill==';
      final controller = RichTextEditingController(text: input);

      expect(controller.text, equals('Standard yellow note and urgent alert plus info pill'));

      // Check text spans have correct background and foreground styling
      final span = controller.buildTextSpan(
        context: null as dynamic,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        withComposing: false,
      );

      final children = span.children!;
      bool foundYellow = false;
      bool foundRed = false;
      bool foundNavy = false;

      for (final child in children) {
        if (child is TextSpan) {
          if (child.text == 'yellow note') {
            expect(child.style?.backgroundColor, equals(const Color(0xFFFEF08A)));
            expect(child.style?.color, equals(const Color(0xFF854D0E)));
            foundYellow = true;
          } else if (child.text == 'urgent alert') {
            expect(child.style?.backgroundColor, equals(const Color(0xFFFECACA)));
            expect(child.style?.color, equals(const Color(0xFF991B1B)));
            foundRed = true;
          } else if (child.text == 'info pill') {
            expect(child.style?.backgroundColor, equals(const Color(0xFF1E3A8A)));
            expect(child.style?.color, equals(const Color(0xFFFFFFFF)));
            foundNavy = true;
          }
        }
      }

      expect(foundYellow, isTrue);
      expect(foundRed, isTrue);
      expect(foundNavy, isTrue);

      // Verify serialization preserves color specifiers
      final serialized = controller.serialize();
      expect(serialized, contains('==yellow note=='));
      expect(serialized, contains('==red:urgent alert=='));
      expect(serialized, contains('==navy:info pill=='));
    });

    test('RichTextEditingController applies and toggles specific highlight colors programmatically', () {
      final controller = RichTextEditingController(text: 'Hello World Flutter');

      // Select 'World' (offset 6 to 11) and apply navy highlight
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11);
      controller.applyHighlightColor(controller.selection, HighlightColor.navyBlue);

      expect(controller.serialize(), equals('Hello ==navy:World== Flutter'));

      // Now toggle off highlight
      controller.toggleHighlight(controller.selection, HighlightColor.navyBlue);
      expect(controller.serialize(), equals('Hello World Flutter'));

      // Apply light red highlight
      controller.applyHighlightColor(controller.selection, HighlightColor.lightRed);
      expect(controller.serialize(), equals('Hello ==red:World== Flutter'));
    });

    testWidgets('RichDescriptionView renders multiple highlight colors properly', (tester) async {
      const formatted = 'Notice: ==red:High Priority== and ==navy:Deep Sea Diving== and ==Simple Note==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RichDescriptionView(description: formatted),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('==red:'), findsNothing);
      expect(find.textContaining('==navy:'), findsNothing);
      expect(find.textContaining('==Simple'), findsNothing);
      expect(find.textContaining('High Priority'), findsWidgets);
      expect(find.textContaining('Deep Sea Diving'), findsWidgets);
      expect(find.textContaining('Simple Note'), findsWidgets);
    });

    test('AddEventDialog supportedImageExtensions strictly limits uploads to image formats', () {
      final exts = AddEventDialog.supportedImageExtensions;

      // Must support standard image formats and GIFs
      expect(exts, contains('png'));
      expect(exts, contains('jpg'));
      expect(exts, contains('jpeg'));
      expect(exts, contains('webp'));
      expect(exts, contains('gif'));
      expect(exts, contains('bmp'));
      expect(exts, contains('heic'));

      // Must NOT include non-image document formats
      expect(exts.contains('pdf'), isFalse);
      expect(exts.contains('doc'), isFalse);
      expect(exts.contains('docx'), isFalse);
      expect(exts.contains('xls'), isFalse);
      expect(exts.contains('xlsx'), isFalse);
      expect(exts.contains('txt'), isFalse);
      expect(exts.contains('zip'), isFalse);
    });
  });
}
