import 'package:flutter/material.dart';

/// Renders the formatting emitted by the agent's rich description editor.
class EventDescription extends StatelessWidget {
  final String text;
  const EventDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    const style =
        TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4);
    final normalized = text
        .replaceAllMapped(
            RegExp(r'^\s{0,3}#{1,6}\s+(.+?)(?:\s+#+)?$', multiLine: true),
            (m) => '**${m[1]}**')
        .replaceAllMapped(
            RegExp(r'^(\s*)[-*+]\s+', multiLine: true), (m) => '${m[1]}• ');
    return Text.rich(TextSpan(children: descriptionSpans(normalized, style)));
  }
}

List<InlineSpan> descriptionSpans(String text, TextStyle style) {
  final pattern = RegExp(
    r'==([\s\S]+?)==|\*\*\*([\s\S]+?)\*\*\*|\*\*([\s\S]+?)\*\*|(?<!\*)\*([^*]+?)\*(?!\*)|<u>([\s\S]*?)</u>|\[([^\]]+)\]\(([^)]*)\)|<(b|strong|i|em|mark)>([\s\S]*?)</\8>',
    caseSensitive: false,
  );
  final spans = <InlineSpan>[];
  var last = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > last)
      spans
          .add(TextSpan(text: text.substring(last, match.start), style: style));
    String inner;
    var next = style;
    if (match[1] != null) {
      inner = match[1]!;
      var background = const Color(0xFFFEF08A);
      var foreground = const Color(0xFF854D0E);
      if (inner.startsWith('red:')) {
        inner = inner.substring(4);
        background = const Color(0xFFFECACA);
        foreground = const Color(0xFF991B1B);
      } else if (inner.startsWith('navy:')) {
        inner = inner.substring(5);
        background = const Color(0xFF1E3A8A);
        foreground = Colors.white;
      }
      next = next.copyWith(backgroundColor: background, color: foreground);
    } else if (match[2] != null) {
      inner = match[2]!;
      next = next.copyWith(
          fontWeight: FontWeight.bold, fontStyle: FontStyle.italic);
    } else if (match[3] != null) {
      inner = match[3]!;
      next = next.copyWith(fontWeight: FontWeight.bold);
    } else if (match[4] != null) {
      inner = match[4]!;
      next = next.copyWith(fontStyle: FontStyle.italic);
    } else if (match[5] != null) {
      inner = match[5]!;
      next = next.copyWith(decoration: TextDecoration.underline);
    } else if (match[6] != null) {
      inner = match[6]!;
      next = next.copyWith(
          color: const Color(0xFF2563EB), decoration: TextDecoration.underline);
    } else {
      inner = match[9]!;
      final tag = match[8]!.toLowerCase();
      if (tag == 'b' || tag == 'strong')
        next = next.copyWith(fontWeight: FontWeight.bold);
      if (tag == 'i' || tag == 'em')
        next = next.copyWith(fontStyle: FontStyle.italic);
      if (tag == 'mark')
        next = next.copyWith(backgroundColor: const Color(0xFFFEF08A));
    }
    spans.add(TextSpan(children: descriptionSpans(inner, next), style: next));
    last = match.end;
  }
  if (last < text.length)
    spans.add(TextSpan(text: text.substring(last), style: style));
  return spans;
}
