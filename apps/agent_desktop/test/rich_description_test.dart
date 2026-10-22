import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_desktop/ui/widgets/rich_description_editor.dart';

void main() {
  group('RichDescriptionSyntax & Editor Tests', () {
    test('RichTextEditingController preserves exact text length and plain text', () {
      const text = 'Here is <b>bold</b>, <i>italic</i>, <mark>highlight</mark>, and [link text](https://example.com) with **markdown bold** and ==yellow==.';
      final controller = RichTextEditingController(text: text);
      final span = controller.buildTextSpan(
        context: null as dynamic,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        withComposing: false,
      );

      // The plain text of the span MUST exactly equal the controller text
      expect(span.toPlainText(includePlaceholders: false), equals(text));
    });

    test('RichDescriptionSyntax identifies bold, italic, highlight, and link styles', () {
      const text = 'Alpha **bold text** Beta <mark>highlighted</mark> Gamma [link label](https://test.com)';
      final controller = RichTextEditingController(text: text);
      final span = controller.buildTextSpan(
        context: null as dynamic,
        style: const TextStyle(fontSize: 14, color: Colors.black),
        withComposing: false,
      );

      expect(span.toPlainText(), equals(text));
      // Verify children spans contain styled elements
      final children = span.children!;
      expect(children.isNotEmpty, isTrue);

      bool foundBold = false;
      bool foundHighlight = false;
      bool foundLink = false;

      for (final s in children) {
        if (s is TextSpan) {
          if (s.text == 'bold text' && s.style?.fontWeight == FontWeight.bold) {
            foundBold = true;
          }
          if (s.text == 'highlighted' && s.style?.backgroundColor == const Color(0xFFFEF08A)) {
            foundHighlight = true;
          }
          if (s.text == 'link label' && s.style?.color == const Color(0xFF2563EB)) {
            foundLink = true;
          }
        }
      }

      expect(foundBold, isTrue, reason: 'Bold text should have FontWeight.bold');
      expect(foundHighlight, isTrue, reason: 'Highlight text should have yellow background Color(0xFFFEF08A)');
      expect(foundLink, isTrue, reason: 'Link text should have blue color Color(0xFF2563EB)');
    });

    testWidgets('RichDescriptionView strips tags and renders formatted spans without literal XML', (tester) async {
      const rawText = 'Welcome to <mark>Zurich</mark>! See <b>Lake Zurich</b> or visit [Official Site](https://zuerich.com).';

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

    testWidgets('RichDescriptionView renders markdown table as a visual Table widget', (tester) async {
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
  });
}
