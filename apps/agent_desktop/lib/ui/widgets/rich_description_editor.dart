import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lucide-style PenLine painter for highlight/pen button.
class PenLinePainter extends CustomPainter {
  final Color color;
  const PenLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.22, size.height * 0.78);
    path.lineTo(size.width * 0.32, size.height * 0.52);
    path.lineTo(size.width * 0.68, size.height * 0.18);
    path.lineTo(size.width * 0.82, size.height * 0.32);
    path.lineTo(size.width * 0.48, size.height * 0.68);
    path.close();

    path.moveTo(size.width * 0.22, size.height * 0.78);
    path.lineTo(size.width * 0.38, size.height * 0.62);

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.82),
      Offset(size.width * 0.88, size.height * 0.82),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PenLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Lucide-style 2x3 table grid painter for table insertion button.
class TableGridPainter extends CustomPainter {
  final Color color;
  const TableGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.12, size.width * 0.76,
          size.height * 0.76),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(rect, paint);

    canvas.drawLine(
      Offset(size.width * 0.50, size.height * 0.12),
      Offset(size.width * 0.50, size.height * 0.88),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.38),
      Offset(size.width * 0.88, size.height * 0.38),
      paint,
    );

    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.62),
      Offset(size.width * 0.88, size.height * 0.62),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant TableGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Lucide-style eraser painter for clear formatting button.
class EraserPainter extends CustomPainter {
  final Color color;
  const EraserPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.30, size.height * 0.78);
    path.lineTo(size.width * 0.68, size.height * 0.22);
    path.lineTo(size.width * 0.84, size.height * 0.38);
    path.lineTo(size.width * 0.46, size.height * 0.82);
    path.close();

    path.moveTo(size.width * 0.44, size.height * 0.58);
    path.lineTo(size.width * 0.60, size.height * 0.74);

    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.82),
      Offset(size.width * 0.55, size.height * 0.82),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant EraserPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Model for an interactive visual table.
class EditableTableData {
  List<String> headers;
  List<List<String>> rows;

  EditableTableData({
    required this.headers,
    required this.rows,
  });

  factory EditableTableData.defaultTable([int r = 2, int c = 3]) {
    final headers = List.generate(c, (i) => 'Header ${i + 1}');
    final rows = List.generate(
      r,
      (rowIdx) =>
          List.generate(c, (colIdx) => 'Cell ${rowIdx + 1}-${colIdx + 1}'),
    );
    return EditableTableData(headers: headers, rows: rows);
  }

  void addRow() {
    rows.add(List.generate(headers.length, (_) => ''));
  }

  void removeRow() {
    if (rows.length > 1) {
      rows.removeLast();
    }
  }

  void addColumn() {
    headers.add('Header ${headers.length + 1}');
    for (final row in rows) {
      row.add('');
    }
  }

  void removeColumn() {
    if (headers.length > 1) {
      headers.removeLast();
      for (final row in rows) {
        if (row.isNotEmpty) row.removeLast();
      }
    }
  }

  String toMarkdown() {
    if (headers.isEmpty) return '';
    final buf = StringBuffer();
    buf.write('| ');
    buf.write(
        headers.map((h) => h.trim().isEmpty ? ' ' : h.trim()).join(' | '));
    buf.writeln(' |');
    buf.write('| ');
    buf.write(headers.map((_) => ':---').join(' | '));
    buf.writeln(' |');
    for (final row in rows) {
      buf.write('| ');
      buf.write(row
          .map((cell) => cell.trim().isEmpty ? ' ' : cell.trim())
          .join(' | '));
      buf.writeln(' |');
    }
    return buf.toString().trim();
  }

  static EditableTableData? parseFromMarkdown(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();
    final tableLines = <String>[];
    for (final l in lines) {
      if (l.startsWith('|') && l.endsWith('|')) {
        tableLines.add(l);
      }
    }
    if (tableLines.length < 2) return null;

    final headerLine = tableLines[0];
    final headers = headerLine
        .substring(1, headerLine.length - 1)
        .split('|')
        .map((h) => h.trim())
        .toList();

    if (headers.isEmpty) return null;

    final rows = <List<String>>[];
    for (int i = 2; i < tableLines.length; i++) {
      final line = tableLines[i];
      final cells = line
          .substring(1, line.length - 1)
          .split('|')
          .map((c) => c.trim())
          .toList();
      while (cells.length < headers.length) {
        cells.add('');
      }
      rows.add(cells.sublist(0, headers.length));
    }
    return EditableTableData(
      headers: headers,
      rows: rows.isEmpty ? [List.generate(headers.length, (_) => '')] : rows,
    );
  }
}

/// Helper to separate paragraph text and embedded markdown tables.
class ExtractedContent {
  final String textWithoutTable;
  final EditableTableData? table;

  ExtractedContent({required this.textWithoutTable, this.table});
}

ExtractedContent extractTableAndText(String raw) {
  final table = EditableTableData.parseFromMarkdown(raw);
  if (table == null) {
    return ExtractedContent(textWithoutTable: raw);
  }

  final lines = raw.split('\n');
  final cleanedLines = <String>[];
  for (final l in lines) {
    final trimmed = l.trim();
    if (!(trimmed.startsWith('|') && trimmed.endsWith('|'))) {
      cleanedLines.add(l);
    }
  }
  final cleanText = cleanedLines.join('\n').trim();
  return ExtractedContent(textWithoutTable: cleanText, table: table);
}

/// Sanitizes text by converting any legacy XML/HTML tags into clean Markdown
/// and removing any stray XML tags.
String sanitizeDescription(String input) {
  var s = input;
  // Convert <mark>...</mark> to ==...==
  s = s.replaceAllMapped(
      RegExp(r'<mark[^>]*>(.*?)</mark>', caseSensitive: false, dotAll: true),
      (m) => '==${m.group(1)}==');
  // Strip <center>...</center>
  s = s.replaceAll(RegExp(r'</?center>', caseSensitive: false), '');
  // Convert <b>...</b> and <strong>...</strong> to **...**
  s = s.replaceAllMapped(
      RegExp(r'<(b|strong)>(.*?)</\1>', caseSensitive: false, dotAll: true),
      (m) => '**${m.group(2)}**');
  // Convert <i>...</i> and <em>...</em> to *...*
  s = s.replaceAllMapped(
      RegExp(r'<(i|em)>(.*?)</\1>', caseSensitive: false, dotAll: true),
      (m) => '*${m.group(2)}*');
  // Convert <u>...</u> to clean text or markdown
  s = s.replaceAllMapped(
      RegExp(r'<u>(.*?)</u>', caseSensitive: false, dotAll: true),
      (m) => '${m.group(1)}');
  // Convert <a href="url">label</a> to [label](url)
  s = s.replaceAllMapped(
      RegExp(r'<a\s+href="([^"]*)">(.*?)</a>',
          caseSensitive: false, dotAll: true),
      (m) => '[${m.group(2)}](${m.group(1)})');
  // Strip any remaining XML/HTML tags
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  return s;
}

/// Style per character for in-editor syntax formatting
class _CharFormat {
  bool isBold = false;
  bool isItalic = false;
  bool isHighlight = false;
  bool isLink = false;
  bool isBullet = false;
  bool isNumber = false;
  bool isDelimiter = false;

  bool matches(_CharFormat other) {
    return isBold == other.isBold &&
        isItalic == other.isItalic &&
        isHighlight == other.isHighlight &&
        isLink == other.isLink &&
        isBullet == other.isBullet &&
        isNumber == other.isNumber &&
        isDelimiter == other.isDelimiter;
  }
}

/// Rich text editing controller that renders live visual styles in the text editor
/// (Bold font, Italic slant, TravChad yellow highlight #FEF08A, Blue links #2563EB)
/// while visually hiding syntax delimiters (fontSize: 0.001) so caret positioning
/// remains 100% accurate without showing ANY raw XML or markdown tags to the user.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  static const Color highlightColor = Color(0xFFFEF08A);
  static const Color highlightTextColor = Color(0xFF854D0E);
  static const Color linkColor = Color(0xFF2563EB);

  @override
  TextSpan buildTextSpan({
    BuildContext? context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle =
        style ?? const TextStyle(fontSize: 14.0, color: Color(0xFF1E293B));
    final rawText = text;

    if (rawText.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final n = rawText.length;
    final flags = List.generate(n, (_) => _CharFormat());

    // 1. Highlight: ==...== and legacy <mark>...</mark>
    final highlightRegex = RegExp(r'(==([^=\n]+)==|<mark[^>]*>(.*?)</mark>)',
        caseSensitive: false, dotAll: true);
    for (final m in highlightRegex.allMatches(rawText)) {
      final matchStr = m.group(0)!;
      if (matchStr.startsWith('==')) {
        flags[m.start].isDelimiter = true;
        flags[m.start + 1].isDelimiter = true;
        for (int i = m.start + 2; i < m.end - 2 && i < n; i++) {
          flags[i].isHighlight = true;
        }
        flags[m.end - 2].isDelimiter = true;
        flags[m.end - 1].isDelimiter = true;
      } else {
        // legacy <mark> tag
        final openEnd = rawText.indexOf('>', m.start) + 1;
        final closeStart = m.end - 7;
        for (int i = m.start; i < openEnd && i < n; i++) {
          flags[i].isDelimiter = true;
        }
        for (int i = openEnd; i < closeStart && i < n; i++) {
          flags[i].isHighlight = true;
        }
        for (int i = closeStart; i < m.end && i < n; i++) {
          flags[i].isDelimiter = true;
        }
      }
    }

    // 2. Bold: **...** and legacy <b>...</b> / <strong>...</strong>
    final bTagRegex =
        RegExp(r'<(b|strong)>(.*?)</\1>', caseSensitive: false, dotAll: true);
    for (final m in bTagRegex.allMatches(rawText)) {
      final openEnd = rawText.indexOf('>', m.start) + 1;
      final closeTagLen = m.group(1)!.length + 3;
      final closeStart = m.end - closeTagLen;
      for (int i = m.start; i < openEnd && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = openEnd; i < closeStart && i < n; i++) {
        flags[i].isBold = true;
      }
      for (int i = closeStart; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final mdBoldRegex = RegExp(r'\*\*([^\*\n]+)\*\*');
    for (final m in mdBoldRegex.allMatches(rawText)) {
      flags[m.start].isDelimiter = true;
      flags[m.start + 1].isDelimiter = true;
      for (int i = m.start + 2; i < m.end - 2 && i < n; i++) {
        flags[i].isBold = true;
      }
      flags[m.end - 2].isDelimiter = true;
      flags[m.end - 1].isDelimiter = true;
    }

    // 3. Italic: *...* and legacy <i>...</i> / <em>...</em>
    final iTagRegex =
        RegExp(r'<(i|em)>(.*?)</\1>', caseSensitive: false, dotAll: true);
    for (final m in iTagRegex.allMatches(rawText)) {
      final openEnd = rawText.indexOf('>', m.start) + 1;
      final closeTagLen = m.group(1)!.length + 3;
      final closeStart = m.end - closeTagLen;
      for (int i = m.start; i < openEnd && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = openEnd; i < closeStart && i < n; i++) {
        flags[i].isItalic = true;
      }
      for (int i = closeStart; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final mdItalicRegex = RegExp(r'(?<!\*)\*([^\*\n]+)\*(?!\*)');
    for (final m in mdItalicRegex.allMatches(rawText)) {
      flags[m.start].isDelimiter = true;
      for (int i = m.start + 1; i < m.end - 1 && i < n; i++) {
        flags[i].isItalic = true;
      }
      flags[m.end - 1].isDelimiter = true;
    }

    // 4. Links: [label](url) and legacy <a href="...">...</a>
    final mdLinkRegex = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)');
    for (final m in mdLinkRegex.allMatches(rawText)) {
      flags[m.start].isDelimiter = true;
      final closeBracket = rawText.indexOf(']', m.start);
      for (int i = m.start + 1; i < closeBracket && i < n; i++) {
        flags[i].isLink = true;
      }
      for (int i = closeBracket; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final htmlLinkRegex = RegExp(r'<a\s+href="([^"]*)">(.*?)</a>',
        caseSensitive: false, dotAll: true);
    for (final m in htmlLinkRegex.allMatches(rawText)) {
      final openEnd = rawText.indexOf('>', m.start) + 1;
      final closeStart = m.end - 4;
      for (int i = m.start; i < openEnd && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = openEnd; i < closeStart && i < n; i++) {
        flags[i].isLink = true;
      }
      for (int i = closeStart; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    // 5. Stray legacy XML tags: <center>, </center>, <u>, </u>
    final strayXmlRegex =
        RegExp(r'</?(center|u|p)[^>]*>', caseSensitive: false);
    for (final m in strayXmlRegex.allMatches(rawText)) {
      for (int i = m.start; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    // 6. Bullets at line start: • or -
    final bulletRegex = RegExp(r'(^|\n)(\s*)([•\-])\s+');
    for (final m in bulletRegex.allMatches(rawText)) {
      final bulletIdx = m.start + m.group(1)!.length + m.group(2)!.length;
      if (bulletIdx < n) {
        flags[bulletIdx].isBullet = true;
      }
    }

    // 7. Numbers at line start: 1. , 2.
    final numberRegex = RegExp(r'(^|\n)(\s*)(\d+\.)\s+');
    for (final m in numberRegex.allMatches(rawText)) {
      final numStart = m.start + m.group(1)!.length + m.group(2)!.length;
      final numEnd = numStart + m.group(3)!.length;
      for (int i = numStart; i < numEnd && i < n; i++) {
        flags[i].isNumber = true;
      }
    }

    // 8. Build contiguous TextSpans
    final spans = <TextSpan>[];
    int start = 0;

    while (start < n) {
      int end = start + 1;
      while (end < n && flags[end].matches(flags[start])) {
        end++;
      }

      final chunk = rawText.substring(start, end);
      final f = flags[start];

      TextStyle chunkStyle = baseStyle;

      if (f.isDelimiter) {
        // Hide delimiters completely from human sight so NO raw tags or markdown marks show!
        chunkStyle = baseStyle.copyWith(
          fontSize: 0.001,
          letterSpacing: -1.0,
          color: Colors.transparent,
        );
      } else {
        if (f.isBold) {
          chunkStyle = chunkStyle.copyWith(fontWeight: FontWeight.bold);
        }
        if (f.isItalic) {
          chunkStyle = chunkStyle.copyWith(fontStyle: FontStyle.italic);
        }
        if (f.isHighlight) {
          chunkStyle = chunkStyle.copyWith(
            backgroundColor: highlightColor,
            color: highlightTextColor,
            fontWeight: f.isBold ? FontWeight.bold : FontWeight.w600,
          );
        }
        if (f.isLink) {
          chunkStyle = chunkStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
            fontWeight: f.isBold ? FontWeight.bold : FontWeight.w600,
          );
        }
        if (f.isBullet) {
          chunkStyle = chunkStyle.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
          );
        }
        if (f.isNumber) {
          chunkStyle = chunkStyle.copyWith(
            color: const Color(0xFF2563EB),
            fontWeight: FontWeight.bold,
          );
        }
      }

      spans.add(TextSpan(text: chunk, style: chunkStyle));
      start = end;
    }

    return TextSpan(children: spans);
  }
}

/// Syntax parser and presentation renderer.
class RichDescriptionSyntax {
  static const Color highlightColor = Color(0xFFFEF08A);
  static const Color highlightTextColor = Color(0xFF854D0E);
  static const Color linkColor = Color(0xFF2563EB);

  static String stripTags(String text) {
    return text
        .replaceAll(RegExp(r'<mark[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</mark>', caseSensitive: false), '')
        .replaceAll('==', '')
        .replaceAll(RegExp(r'</?b>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?strong>', caseSensitive: false), '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'</?i>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?em>', caseSensitive: false), '')
        .replaceAll(RegExp(r'(?<!\*)\*(?!\*)'), '')
        .replaceAll(RegExp(r'</?u>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?center>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<!--\s*align:[^>]*-->'), '')
        .replaceAll(
            RegExp(r'<a\s+href="[^"]*">(.*?)</a>', caseSensitive: false), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
  }

  static List<InlineSpan> parseInlineSpans(
    String line,
    TextStyle baseStyle, {
    void Function(String url)? onOpenUrl,
  }) {
    if (line.isEmpty) return [TextSpan(text: '', style: baseStyle)];

    final tokenRegex = RegExp(
      r'(<mark[^>]*>.*?</mark>|==[^=\n]+==|'
      r'<b>.*?</b>|<strong>.*?</strong>|\*\*[^\*\n]+\*\*|'
      r'<i>.*?</i>|<em>.*?</em>|(?<!\*)\*[^\*\n]+\*(?!\*)|'
      r'\[([^\]\n]+)\]\(([^)\n]*)\)|'
      r'<a\s+href="([^"]*)">(.*?)</a>|'
      r'https?://[^\s<>"]+)',
      caseSensitive: false,
      dotAll: true,
    );

    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in tokenRegex.allMatches(line)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: line.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final matchedStr = match.group(0)!;

      // Highlight
      if (matchedStr.toLowerCase().startsWith('<mark')) {
        final inner = matchedStr.substring(
            matchedStr.indexOf('>') + 1, matchedStr.length - 7);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(
            backgroundColor: highlightColor,
            color: highlightTextColor,
            fontWeight: FontWeight.w600,
          ),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.startsWith('==') &&
          matchedStr.endsWith('==') &&
          matchedStr.length >= 4) {
        final inner = matchedStr.substring(2, matchedStr.length - 2);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(
            backgroundColor: highlightColor,
            color: highlightTextColor,
            fontWeight: FontWeight.w600,
          ),
          onOpenUrl: onOpenUrl,
        ));
      }
      // Bold
      else if (matchedStr.toLowerCase().startsWith('<b>')) {
        final inner = matchedStr.substring(3, matchedStr.length - 4);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontWeight: FontWeight.bold),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.toLowerCase().startsWith('<strong>')) {
        final inner = matchedStr.substring(8, matchedStr.length - 9);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontWeight: FontWeight.bold),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.startsWith('**') &&
          matchedStr.endsWith('**') &&
          matchedStr.length >= 4) {
        final inner = matchedStr.substring(2, matchedStr.length - 2);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontWeight: FontWeight.bold),
          onOpenUrl: onOpenUrl,
        ));
      }
      // Italic
      else if (matchedStr.toLowerCase().startsWith('<i>')) {
        final inner = matchedStr.substring(3, matchedStr.length - 4);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.toLowerCase().startsWith('<em>')) {
        final inner = matchedStr.substring(4, matchedStr.length - 5);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.startsWith('*') &&
          matchedStr.endsWith('*') &&
          matchedStr.length >= 2) {
        final inner = matchedStr.substring(1, matchedStr.length - 1);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          onOpenUrl: onOpenUrl,
        ));
      }
      // Markdown Link [label](url)
      else if (matchedStr.startsWith('[')) {
        final label = match.group(2) ?? '';
        final url = match.group(3) ?? '';
        spans.add(_buildClickableLinkSpan(label, url, baseStyle, onOpenUrl));
      }
      // HTML Link <a href="...">...</a>
      else if (matchedStr.toLowerCase().startsWith('<a')) {
        final url = match.group(4) ?? '';
        final label = match.group(5) ?? url;
        spans.add(_buildClickableLinkSpan(label, url, baseStyle, onOpenUrl));
      }
      // Raw URL
      else if (matchedStr.startsWith('http://') ||
          matchedStr.startsWith('https://')) {
        spans.add(_buildClickableLinkSpan(
            matchedStr, matchedStr, baseStyle, onOpenUrl));
      } else {
        spans.add(TextSpan(text: matchedStr, style: baseStyle));
      }

      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }

  static InlineSpan _buildClickableLinkSpan(
    String label,
    String url,
    TextStyle baseStyle,
    void Function(String url)? onOpenUrl,
  ) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (onOpenUrl != null) {
              onOpenUrl(url);
            } else {
              RichDescriptionView.defaultOpenUrl(url);
            }
          },
          child: Text(
            label,
            style: baseStyle.copyWith(
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// A read-only presentation widget that parses rich descriptions (bold, italics,
/// yellow highlight #FEF08A, blue clickable links #2563EB, visual tables, bullet/numbered lists,
/// and alignment) and renders them cleanly with ZERO raw XML/HTML tags visible.
class RichDescriptionView extends StatelessWidget {
  final String description;
  final String? mapUrl;
  final TextStyle? style;
  final void Function(String url)? onOpenUrl;

  const RichDescriptionView({
    super.key,
    required this.description,
    this.mapUrl,
    this.style,
    this.onOpenUrl,
  });

  static void defaultOpenUrl(String url) {
    if (url.trim().isEmpty) return;
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [url]);
      } else if (Platform.isMacOS) {
        Process.run('open', [url]);
      } else {
        Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    String fullText = description.trim();
    if (mapUrl != null && mapUrl!.isNotEmpty && !fullText.contains(mapUrl!)) {
      if (fullText.isNotEmpty) {
        fullText = '$fullText\n\nLocation: [Open Location Map]($mapUrl)';
      } else {
        fullText = 'Location: [Open Location Map]($mapUrl)';
      }
    }

    if (fullText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Detect alignment metadata
    TextAlign textAlign = TextAlign.left;
    if (fullText.contains('<!-- align:center -->') ||
        fullText.contains('<!--align:center-->') ||
        fullText.contains('<center>')) {
      textAlign = TextAlign.center;
    } else if (fullText.contains('<!-- align:right -->') ||
        fullText.contains('<!--align:right-->')) {
      textAlign = TextAlign.right;
    }

    fullText = sanitizeDescription(fullText);

    final defaultStyle = style ??
        const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF334155),
          height: 1.55,
        );

    final blocks = _parseBlocks(fullText);

    return Column(
      crossAxisAlignment: textAlign == TextAlign.center
          ? CrossAxisAlignment.center
          : (textAlign == TextAlign.right
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start),
      children:
          blocks.map((b) => _renderBlock(b, defaultStyle, textAlign)).toList(),
    );
  }

  List<_DescriptionBlock> _parseBlocks(String text) {
    final rawLines = text.split('\n');
    final blocks = <_DescriptionBlock>[];
    int i = 0;

    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        blocks.add(_DescriptionBlock(type: _BlockType.spacer, lines: []));
        i++;
        continue;
      }

      // 1. Table detection
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final tableLines = <String>[];
        while (i < rawLines.length &&
            rawLines[i].trim().startsWith('|') &&
            rawLines[i].trim().endsWith('|')) {
          tableLines.add(rawLines[i].trim());
          i++;
        }
        blocks
            .add(_DescriptionBlock(type: _BlockType.table, lines: tableLines));
        continue;
      }

      // 2. Bullet list item: starts with • or - or *
      final bulletMatch = RegExp(r'^\s*[-•\*]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        blocks.add(_DescriptionBlock(
            type: _BlockType.bullet, lines: [bulletMatch.group(1)!]));
        i++;
        continue;
      }

      // 3. Numbered list item: starts with 1. 2. etc
      final numMatch = RegExp(r'^\s*(\d+)\.\s+(.*)$').firstMatch(line);
      if (numMatch != null) {
        blocks.add(_DescriptionBlock(
          type: _BlockType.numbered,
          lines: [numMatch.group(2)!],
          metadata: numMatch.group(1),
        ));
        i++;
        continue;
      }

      // 4. Regular paragraph
      blocks.add(_DescriptionBlock(type: _BlockType.paragraph, lines: [line]));
      i++;
    }

    return blocks;
  }

  Widget _renderBlock(
      _DescriptionBlock block, TextStyle baseStyle, TextAlign textAlign) {
    switch (block.type) {
      case _BlockType.spacer:
        return const SizedBox(height: 6);

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8, left: 4),
                child: Text('•',
                    style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: RichDescriptionSyntax.parseInlineSpans(
                      block.lines.first,
                      baseStyle,
                      onOpenUrl: onOpenUrl,
                    ),
                  ),
                  textAlign: textAlign,
                ),
              ),
            ],
          ),
        );

      case _BlockType.numbered:
        final numLabel = block.metadata ?? '1';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8, left: 4),
                child: Text('$numLabel.',
                    style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: RichDescriptionSyntax.parseInlineSpans(
                      block.lines.first,
                      baseStyle,
                      onOpenUrl: onOpenUrl,
                    ),
                  ),
                  textAlign: textAlign,
                ),
              ),
            ],
          ),
        );

      case _BlockType.table:
        return _renderTable(block.lines, baseStyle);

      case _BlockType.paragraph:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Text.rich(
            TextSpan(
              children: RichDescriptionSyntax.parseInlineSpans(
                block.lines.first,
                baseStyle,
                onOpenUrl: onOpenUrl,
              ),
            ),
            textAlign: textAlign,
          ),
        );
    }
  }

  Widget _renderTable(List<String> lines, TextStyle baseStyle) {
    final parsedRows = <List<String>>[];
    for (final line in lines) {
      final parts = line.split('|').map((s) => s.trim()).toList();
      if (parts.isNotEmpty && parts.first.isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();

      final isSeparator = parts.every((p) => RegExp(r'^:?-+:?$').hasMatch(p));
      if (!isSeparator && parts.isNotEmpty) {
        parsedRows.add(parts);
      }
    }

    if (parsedRows.isEmpty) return const SizedBox.shrink();

    final maxCols = parsedRows.map((r) => r.length).reduce(max);
    final headerRow = parsedRows.first;
    final bodyRows =
        parsedRows.length > 1 ? parsedRows.sublist(1) : <List<String>>[];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        border: TableBorder.all(color: const Color(0xFFE2E8F0), width: 1.0),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header Row
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: List.generate(maxCols, (c) {
              final cellText = c < headerRow.length ? headerRow[c] : '';
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text(
                  cellText,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B)),
                ),
              );
            }),
          ),
          // Body Rows
          ...List.generate(bodyRows.length, (r) {
            final row = bodyRows[r];
            final isEven = r % 2 == 0;
            return TableRow(
              decoration: BoxDecoration(
                  color: isEven ? Colors.white : const Color(0xFFFBFDFE)),
              children: List.generate(maxCols, (c) {
                final cellText = c < row.length ? row[c] : '';
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    cellText,
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF334155)),
                  ),
                );
              }),
            );
          }),
        ],
      ),
    );
  }
}

enum _BlockType { paragraph, bullet, numbered, table, spacer }

class _DescriptionBlock {
  final _BlockType type;
  final List<String> lines;
  final String? metadata;

  _DescriptionBlock({
    required this.type,
    required this.lines,
    this.metadata,
  });
}

/// Rich Description Editor box with toolbar matching the TravChad / Lucide design,
/// supporting real keyboard shortcuts (Ctrl+B, Ctrl+I, Ctrl+H, Ctrl+Z, Ctrl+Y),
/// bullet & numbered lists with auto-continuation, true text alignment,
/// and interactive visual tables without ANY raw XML tags.
class RichDescriptionEditor extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final int minLines;
  final int? maxLines;
  final bool isFullscreen;
  final VoidCallback? onExitFullscreen;

  const RichDescriptionEditor({
    super.key,
    required this.controller,
    this.placeholder = 'Write description here...',
    this.minLines = 5,
    this.maxLines = 10,
    this.isFullscreen = false,
    this.onExitFullscreen,
  });

  @override
  State<RichDescriptionEditor> createState() => _RichDescriptionEditorState();
}

class _RichDescriptionEditorState extends State<RichDescriptionEditor> {
  final FocusNode _focusNode = FocusNode();
  final List<TextEditingValue> _history = [];
  int _historyIndex = -1;
  bool _isPerformingUndoRedo = false;
  late final RichTextEditingController _effectiveController;

  TextAlign _textAlign = TextAlign.left;
  EditableTableData? _tableData;

  @override
  void initState() {
    super.initState();

    var rawInitial = widget.controller.text;

    // Detect alignment from metadata
    if (rawInitial.contains('<!-- align:center -->') ||
        rawInitial.contains('<!--align:center-->') ||
        rawInitial.contains('<center>')) {
      _textAlign = TextAlign.center;
    } else if (rawInitial.contains('<!-- align:right -->') ||
        rawInitial.contains('<!--align:right-->')) {
      _textAlign = TextAlign.right;
    }

    // Sanitize any legacy XML tags
    final sanitized = sanitizeDescription(rawInitial);

    // Extract table if present
    final extracted = extractTableAndText(sanitized);
    _tableData = extracted.table;

    _effectiveController =
        RichTextEditingController(text: extracted.textWithoutTable);
    _effectiveController.selection = widget.controller.selection;

    _effectiveController.addListener(_syncToWidgetController);
    widget.controller.addListener(_syncFromWidgetController);

    _pushHistory(_effectiveController.value);
    _effectiveController.addListener(_onTextChanged);
  }

  void _syncToWidgetController() {
    String full = _effectiveController.text;
    if (_textAlign == TextAlign.center) {
      full = '<!-- align:center -->\n$full';
    } else if (_textAlign == TextAlign.right) {
      full = '<!-- align:right -->\n$full';
    }
    if (_tableData != null && _tableData!.headers.isNotEmpty) {
      final tableMd = _tableData!.toMarkdown();
      if (tableMd.isNotEmpty) {
        full = full.trim().isEmpty ? tableMd : '${full.trim()}\n\n$tableMd';
      }
    }
    if (widget.controller.text != full) {
      widget.controller.value = TextEditingValue(
        text: full,
        selection: _effectiveController.selection,
      );
    }
  }

  void _syncFromWidgetController() {
    final raw = widget.controller.text;
    if (raw.isEmpty && _effectiveController.text.isNotEmpty) {
      _effectiveController.text = '';
      _tableData = null;
    }
    if (widget.controller.selection.isValid &&
        widget.controller.selection != _effectiveController.selection) {
      _effectiveController.selection = widget.controller.selection;
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChanged);
    _effectiveController.removeListener(_syncToWidgetController);
    widget.controller.removeListener(_syncFromWidgetController);
    _effectiveController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isPerformingUndoRedo) return;
    if (_history.isEmpty ||
        _history[_historyIndex].text != _effectiveController.text) {
      _pushHistory(_effectiveController.value);
    }
  }

  void _pushHistory(TextEditingValue value) {
    if (_historyIndex >= 0 && _historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(value);
    if (_history.length > 50) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
    if (mounted) setState(() {});
  }

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo =>
      _historyIndex >= 0 && _historyIndex < _history.length - 1;

  void _undo() {
    if (!_canUndo) return;
    _isPerformingUndoRedo = true;
    _historyIndex--;
    _effectiveController.value = _history[_historyIndex];
    _isPerformingUndoRedo = false;
    setState(() {});
  }

  void _redo() {
    if (!_canRedo) return;
    _isPerformingUndoRedo = true;
    _historyIndex++;
    _effectiveController.value = _history[_historyIndex];
    _isPerformingUndoRedo = false;
    setState(() {});
  }

  // --- Keyboard Shortcuts & Event Handling ---
  void _toggleBold() => _toggleWrap('**', '**');
  void _toggleItalic() => _toggleWrap('*', '*');
  void _toggleHighlight() => _toggleWrap('==', '==');

  void _toggleWrap(String prefix, String suffix) {
    var selection = _effectiveController.selection;
    if ((!selection.isValid || selection.isCollapsed) &&
        widget.controller.selection.isValid &&
        !widget.controller.selection.isCollapsed) {
      selection = widget.controller.selection;
    }
    final text = _effectiveController.text;

    if (!selection.isValid || selection.isCollapsed) {
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);

      if (selectedText.startsWith(prefix) &&
          selectedText.endsWith(suffix) &&
          selectedText.length >= prefix.length + suffix.length) {
        // Unwrap
        final innerText = selectedText.substring(
            prefix.length, selectedText.length - suffix.length);
        final newText =
            text.replaceRange(selection.start, selection.end, innerText);
        _effectiveController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
              baseOffset: selection.start,
              extentOffset: selection.start + innerText.length),
        );
      } else {
        // Wrap
        final newText = text.replaceRange(
            selection.start, selection.end, '$prefix$selectedText$suffix');
        _effectiveController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(
              baseOffset: selection.start,
              extentOffset: selection.start +
                  prefix.length +
                  selectedText.length +
                  suffix.length),
        );
      }
    }
    _syncToWidgetController();
    _focusNode.requestFocus();
  }

  // Auto-continue bullet or numbered lists on Enter
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      final text = _effectiveController.text;
      final selection = _effectiveController.selection;
      if (selection.isValid && selection.isCollapsed) {
        final cursor = selection.start;
        final lineStart =
            cursor <= 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
        final currentLine = text.substring(lineStart, cursor);

        // 1. Check Bullet List
        final bulletMatch = RegExp(r'^(\s*)([•\-])\s+').firstMatch(currentLine);
        if (bulletMatch != null) {
          final indent = bulletMatch.group(1) ?? '';
          final bulletChar = bulletMatch.group(2) ?? '•';
          final contentAfter = currentLine.substring(bulletMatch.end).trim();

          if (contentAfter.isEmpty) {
            // Empty bullet: exit list
            final newText = text.replaceRange(lineStart, cursor, '');
            _effectiveController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStart),
            );
            return KeyEventResult.handled;
          } else {
            // Continue bullet
            final prefix = '\n$indent$bulletChar ';
            final newText = text.replaceRange(cursor, cursor, prefix);
            _effectiveController.value = TextEditingValue(
              text: newText,
              selection:
                  TextSelection.collapsed(offset: cursor + prefix.length),
            );
            return KeyEventResult.handled;
          }
        }

        // 2. Check Numbered List
        final numMatch = RegExp(r'^(\s*)(\d+)\.\s+').firstMatch(currentLine);
        if (numMatch != null) {
          final indent = numMatch.group(1) ?? '';
          final numVal = int.parse(numMatch.group(2)!);
          final contentAfter = currentLine.substring(numMatch.end).trim();

          if (contentAfter.isEmpty) {
            // Empty number: exit list
            final newText = text.replaceRange(lineStart, cursor, '');
            _effectiveController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStart),
            );
            return KeyEventResult.handled;
          } else {
            // Continue numbering
            final prefix = '\n$indent${numVal + 1}. ';
            final newText = text.replaceRange(cursor, cursor, prefix);
            _effectiveController.value = TextEditingValue(
              text: newText,
              selection:
                  TextSelection.collapsed(offset: cursor + prefix.length),
            );
            return KeyEventResult.handled;
          }
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _toggleBulletList() {
    final text = _effectiveController.text;
    var selection = _effectiveController.selection;
    if ((!selection.isValid || selection.isCollapsed) &&
        widget.controller.selection.isValid &&
        !widget.controller.selection.isCollapsed) {
      selection = widget.controller.selection;
    }
    if (!selection.isValid) return;

    final start = selection.start;
    final end = selection.end;

    final lineStart = start <= 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final lineEnd = text.indexOf('\n', end);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;

    final selectedLines = text.substring(lineStart, effectiveEnd).split('\n');
    final allBulleted = selectedLines
        .every((l) => l.trim().startsWith('• ') || l.trim().startsWith('- '));

    final newLines = selectedLines.map((l) {
      if (allBulleted) {
        return l.replaceFirst(RegExp(r'^\s*([•\-])\s*'), '');
      } else {
        if (l.trim().isEmpty) return l;
        if (l.trim().startsWith('• ') || l.trim().startsWith('- ')) return l;
        final cleaned = l.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
        return '• $cleaned';
      }
    }).toList();

    final replacement = newLines.join('\n');
    final newText = text.replaceRange(lineStart, effectiveEnd, replacement);
    _effectiveController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
          baseOffset: lineStart, extentOffset: lineStart + replacement.length),
    );
    _syncToWidgetController();
    _focusNode.requestFocus();
  }

  void _toggleNumberedList() {
    final text = _effectiveController.text;
    var selection = _effectiveController.selection;
    if ((!selection.isValid || selection.isCollapsed) &&
        widget.controller.selection.isValid &&
        !widget.controller.selection.isCollapsed) {
      selection = widget.controller.selection;
    }
    if (!selection.isValid) return;

    final start = selection.start;
    final end = selection.end;

    final lineStart = start <= 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final lineEnd = text.indexOf('\n', end);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;

    final selectedLines = text.substring(lineStart, effectiveEnd).split('\n');
    final allNumbered =
        selectedLines.every((l) => RegExp(r'^\s*\d+\.\s*').hasMatch(l));

    int count = 1;
    final newLines = selectedLines.map((l) {
      if (allNumbered) {
        return l.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
      } else {
        if (l.trim().isEmpty) return l;
        final cleaned = l.replaceFirst(RegExp(r'^\s*([•\-]|\d+\.)\s*'), '');
        final res = '$count. $cleaned';
        count++;
        return res;
      }
    }).toList();

    final replacement = newLines.join('\n');
    final newText = text.replaceRange(lineStart, effectiveEnd, replacement);
    _effectiveController.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
          baseOffset: lineStart, extentOffset: lineStart + replacement.length),
    );
    _syncToWidgetController();
    _focusNode.requestFocus();
  }

  void _setAlignment(TextAlign align) {
    setState(() {
      _textAlign = align;
    });
    _syncToWidgetController();
    _focusNode.requestFocus();
  }

  void _clearFormatting() {
    final text = _effectiveController.text;
    var selection = _effectiveController.selection;
    if ((!selection.isValid || selection.isCollapsed) &&
        widget.controller.selection.isValid &&
        !widget.controller.selection.isCollapsed) {
      selection = widget.controller.selection;
    }

    if (!selection.isValid || selection.isCollapsed) {
      final cleaned = RichDescriptionSyntax.stripTags(text)
          .replaceAll(RegExp(r'^\s*[-•\*]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

      _effectiveController.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    } else {
      final selectedText = selection.textInside(text);
      final cleaned = RichDescriptionSyntax.stripTags(selectedText)
          .replaceAll(RegExp(r'^\s*[-•\*]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

      final newText =
          text.replaceRange(selection.start, selection.end, cleaned);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
            baseOffset: selection.start,
            extentOffset: selection.start + cleaned.length),
      );
    }
    _syncToWidgetController();
    _focusNode.requestFocus();
  }

  void _toggleTable() {
    setState(() {
      if (_tableData == null) {
        _tableData = EditableTableData.defaultTable(2, 3);
      } else {
        _tableData!.addRow();
      }
    });
    _syncToWidgetController();
  }

  void _showInsertLinkDialog() {
    final linkTextCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final selection = _effectiveController.selection;
    if (selection.isValid && !selection.isCollapsed) {
      linkTextCtrl.text = selection.textInside(_effectiveController.text);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: Color(0xFF2563EB), size: 22),
            SizedBox(width: 8),
            Text('Insert Link',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: linkTextCtrl,
                decoration: InputDecoration(
                  labelText: 'Link Text',
                  hintText: 'e.g. Official Site',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final label = linkTextCtrl.text.trim().isEmpty
                  ? 'Link'
                  : linkTextCtrl.text.trim();
              final url = urlCtrl.text.trim().isEmpty
                  ? 'https://'
                  : urlCtrl.text.trim();
              final mdLink = '[$label]($url)';

              final text = _effectiveController.text;
              if (selection.isValid && !selection.isCollapsed) {
                final newText =
                    text.replaceRange(selection.start, selection.end, mdLink);
                _effectiveController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(
                      offset: selection.start + mdLink.length),
                );
              } else {
                final offset =
                    selection.isValid ? selection.start : text.length;
                final newText = text.replaceRange(offset, offset, mdLink);
                _effectiveController.value = TextEditingValue(
                  text: newText,
                  selection:
                      TextSelection.collapsed(offset: offset + mdLink.length),
                );
              }
              _focusNode.requestFocus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Insert Link',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _toggleFullscreen() {
    if (widget.isFullscreen && widget.onExitFullscreen != null) {
      widget.onExitFullscreen!();
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 1000,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description Editor (Fullscreen)',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RichDescriptionEditor(
                    controller: widget.controller,
                    placeholder: widget.placeholder,
                    minLines: 20,
                    maxLines: null,
                    isFullscreen: true,
                    onExitFullscreen: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  // --- Toolbar Button Builder ---
  Widget _buildIconButton({
    Widget? customWidget,
    IconData? icon,
    String? text,
    required String tooltip,
    required VoidCallback? onPressed,
    bool enabled = true,
    bool active = false,
  }) {
    final activeColor = active
        ? const Color(0xFF2563EB)
        : (enabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1));

    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? const Color(0xFFEFF6FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(6),
          hoverColor: const Color(0xFFF1F5F9),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
                  )
                : null,
            child: customWidget ??
                (text != null
                    ? Text(
                        text,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight:
                              text == 'B' ? FontWeight.w800 : FontWeight.w600,
                          fontStyle:
                              text == 'I' ? FontStyle.italic : FontStyle.normal,
                          color: activeColor,
                        ),
                      )
                    : Icon(icon, size: 16, color: activeColor)),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildTableActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF2563EB)),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveTableCard() {
    if (_tableData == null) return const SizedBox.shrink();

    final table = _tableData!;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded,
                    size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Text(
                  'Table',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${table.rows.length} rows × ${table.headers.length} cols',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB)),
                  ),
                ),
                const Spacer(),
                // Actions
                _buildTableActionButton(
                  label: '+ Row',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    setState(() => table.addRow());
                    _syncToWidgetController();
                  },
                ),
                const SizedBox(width: 6),
                if (table.rows.length > 1) ...[
                  _buildTableActionButton(
                    label: '- Row',
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      setState(() => table.removeRow());
                      _syncToWidgetController();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                _buildTableActionButton(
                  label: '+ Col',
                  icon: Icons.add_rounded,
                  onPressed: () {
                    setState(() => table.addColumn());
                    _syncToWidgetController();
                  },
                ),
                const SizedBox(width: 6),
                if (table.headers.length > 1) ...[
                  _buildTableActionButton(
                    label: '- Col',
                    icon: Icons.remove_rounded,
                    onPressed: () {
                      setState(() => table.removeColumn());
                      _syncToWidgetController();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                IconButton(
                  tooltip: 'Delete Table',
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Color(0xFFDC2626)),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    setState(() => _tableData = null);
                    _syncToWidgetController();
                  },
                ),
              ],
            ),
          ),

          // Visual Table Grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(
                color: const Color(0xFFCBD5E1),
                width: 1.0,
                borderRadius: BorderRadius.circular(6),
              ),
              children: [
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: List.generate(table.headers.length, (colIdx) {
                    return Container(
                      width: 140,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: TextFormField(
                        key:
                            ValueKey('tbl_hdr_${table.headers.length}_$colIdx'),
                        initialValue: table.headers[colIdx],
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          border: InputBorder.none,
                          hintText: 'Header',
                          hintStyle: TextStyle(
                              fontSize: 12.5, color: Color(0xFF94A3B8)),
                        ),
                        onChanged: (val) {
                          table.headers[colIdx] = val;
                          _syncToWidgetController();
                        },
                      ),
                    );
                  }),
                ),
                // Data Rows
                ...List.generate(table.rows.length, (rowIdx) {
                  final isEven = rowIdx % 2 == 0;
                  return TableRow(
                    decoration: BoxDecoration(
                        color: isEven ? Colors.white : const Color(0xFFFBFDFE)),
                    children: List.generate(table.headers.length, (colIdx) {
                      final cellVal = colIdx < table.rows[rowIdx].length
                          ? table.rows[rowIdx][colIdx]
                          : '';
                      return Container(
                        width: 140,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: TextFormField(
                          key: ValueKey(
                              'tbl_cell_${table.rows.length}_${table.headers.length}_${rowIdx}_$colIdx'),
                          initialValue: cellVal,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF334155),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 6),
                            border: InputBorder.none,
                            hintText: 'Cell',
                            hintStyle: TextStyle(
                                fontSize: 12.5, color: Color(0xFFCBD5E1)),
                          ),
                          onChanged: (val) {
                            while (table.rows[rowIdx].length <= colIdx) {
                              table.rows[rowIdx].add('');
                            }
                            table.rows[rowIdx][colIdx] = val;
                            _syncToWidgetController();
                          },
                        ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _toggleBold,
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): _toggleBold,
        const SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _toggleItalic,
        const SingleActivator(LogicalKeyboardKey.keyI, meta: true):
            _toggleItalic,
        const SingleActivator(LogicalKeyboardKey.keyH, control: true):
            _toggleHighlight,
        const SingleActivator(LogicalKeyboardKey.keyH, meta: true):
            _toggleHighlight,
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyY, meta: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): _redo,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
            _redo,
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toolbar matching uploaded image
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  // Group 1: B, I, PenLine, Link
                  _buildIconButton(
                    text: 'B',
                    tooltip: 'Bold (Ctrl+B)',
                    onPressed: _toggleBold,
                  ),
                  _buildIconButton(
                    text: 'I',
                    tooltip: 'Italic (Ctrl+I)',
                    onPressed: _toggleItalic,
                  ),
                  _buildIconButton(
                    customWidget: const CustomPaint(
                      size: Size(16, 16),
                      painter: PenLinePainter(color: Color(0xFF475569)),
                    ),
                    tooltip: 'Highlight Text (Ctrl+H)',
                    onPressed: _toggleHighlight,
                  ),
                  _buildIconButton(
                    icon: Icons.link_rounded,
                    tooltip: 'Insert Link',
                    onPressed: _showInsertLinkDialog,
                  ),

                  _buildDivider(),

                  // Group 2: Bullet List, Numbered List, Align Left, Align Center, Table
                  _buildIconButton(
                    icon: Icons.format_list_bulleted_rounded,
                    tooltip: 'Bulleted List',
                    onPressed: _toggleBulletList,
                  ),
                  _buildIconButton(
                    icon: Icons.format_list_numbered_rounded,
                    tooltip: 'Numbered List',
                    onPressed: _toggleNumberedList,
                  ),
                  _buildIconButton(
                    icon: Icons.format_align_left_rounded,
                    tooltip: 'Align Left',
                    active: _textAlign == TextAlign.left,
                    onPressed: () => _setAlignment(TextAlign.left),
                  ),
                  _buildIconButton(
                    icon: Icons.format_align_center_rounded,
                    tooltip: 'Align Center',
                    active: _textAlign == TextAlign.center,
                    onPressed: () => _setAlignment(TextAlign.center),
                  ),
                  _buildIconButton(
                    customWidget: CustomPaint(
                      size: const Size(16, 16),
                      painter: TableGridPainter(
                        color: _tableData != null
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF475569),
                      ),
                    ),
                    tooltip:
                        _tableData == null ? 'Insert Table' : 'Add Table Row',
                    active: _tableData != null,
                    onPressed: _toggleTable,
                  ),

                  _buildDivider(),

                  // Group 3: Eraser / Clear Formatting
                  _buildIconButton(
                    customWidget: const CustomPaint(
                      size: Size(16, 16),
                      painter: EraserPainter(color: Color(0xFF475569)),
                    ),
                    tooltip: 'Clear Formatting',
                    onPressed: _clearFormatting,
                  ),

                  const Spacer(),

                  // Group 4: Undo, Redo
                  _buildIconButton(
                    icon: Icons.undo_rounded,
                    tooltip: 'Undo (Ctrl+Z)',
                    enabled: _canUndo,
                    onPressed: _canUndo ? _undo : null,
                  ),
                  _buildIconButton(
                    icon: Icons.redo_rounded,
                    tooltip: 'Redo (Ctrl+Y)',
                    enabled: _canRedo,
                    onPressed: _canRedo ? _redo : null,
                  ),

                  _buildDivider(),

                  // Group 5: Fullscreen / Maximize
                  _buildIconButton(
                    icon: widget.isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.crop_free_rounded,
                    tooltip:
                        widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                    onPressed: _toggleFullscreen,
                  ),
                ],
              ),
            ),

            // Editable Canvas
            Focus(
              onKeyEvent: _handleKeyEvent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _effectiveController,
                      focusNode: _focusNode,
                      textAlign: _textAlign,
                      minLines: widget.isFullscreen ? 15 : widget.minLines,
                      maxLines: widget.isFullscreen ? null : widget.maxLines,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    ),

                    // Interactive Visual Table
                    if (_tableData != null) _buildInteractiveTableCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
