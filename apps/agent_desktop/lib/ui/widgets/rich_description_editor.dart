import 'dart:io';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
  bool shouldRepaint(covariant PenLinePainter oldDelegate) => oldDelegate.color != color;
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
      Rect.fromLTWH(size.width * 0.12, size.height * 0.12, size.width * 0.76, size.height * 0.76),
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
  bool shouldRepaint(covariant TableGridPainter oldDelegate) => oldDelegate.color != color;
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
  bool shouldRepaint(covariant EraserPainter oldDelegate) => oldDelegate.color != color;
}

/// Style per character for in-editor syntax highlighting
class _CharFormat {
  bool isBold = false;
  bool isItalic = false;
  bool isHighlight = false;
  bool isLink = false;
  bool isUnderline = false;
  bool isStrike = false;
  bool isDelimiter = false;
  Color? delimiterColor;

  bool matches(_CharFormat other) {
    return isBold == other.isBold &&
        isItalic == other.isItalic &&
        isHighlight == other.isHighlight &&
        isLink == other.isLink &&
        isUnderline == other.isUnderline &&
        isStrike == other.isStrike &&
        isDelimiter == other.isDelimiter &&
        delimiterColor == other.delimiterColor;
  }
}

/// Rich text editing controller that renders live visual styles in the text editor
/// (Bold font, Italic slant, TravChad yellow highlight #FEF08A, Blue links #2563EB)
/// while subtly dimming syntax delimiters so caret positioning remains 100% accurate.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext? context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle(fontSize: 14, color: Color(0xFF1E293B), height: 1.5);
    return RichDescriptionSyntax.buildEditorSpan(text, baseStyle);
  }
}

/// Syntax parser & converter for TravChad rich descriptions
class RichDescriptionSyntax {
  static const Color highlightColor = Color(0xFFFEF08A);
  static const Color highlightTextColor = Color(0xFF0F172A);
  static const Color linkColor = Color(0xFF2563EB);

  /// Builds a TextSpan for the editor where the exact string characters are preserved,
  /// but formatted sections display their live visual styles.
  static TextSpan buildEditorSpan(String text, TextStyle baseStyle) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: baseStyle);
    }

    final n = text.length;
    final flags = List<_CharFormat>.generate(n, (_) => _CharFormat());

    // 1. Highlight tags: <mark>...</mark>, <mark style="...">...</mark>, ==...==
    final markRegex = RegExp(r'<mark[^>]*>(.*?)</mark>', caseSensitive: false, dotAll: true);
    for (final m in markRegex.allMatches(text)) {
      final openTagEnd = text.indexOf('>', m.start) + 1;
      final closeTagStart = m.end - 7; // </mark> is 7 chars

      for (int i = m.start; i < openTagEnd && i < n; i++) {
        flags[i].isDelimiter = true;
        flags[i].delimiterColor = const Color(0xFFCA8A04);
      }
      for (int i = openTagEnd; i < closeTagStart && i < n; i++) {
        flags[i].isHighlight = true;
      }
      for (int i = closeTagStart; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
        flags[i].delimiterColor = const Color(0xFFCA8A04);
      }
    }

    final eqHighlightRegex = RegExp(r'==([^=\n]+)==');
    for (final m in eqHighlightRegex.allMatches(text)) {
      flags[m.start].isDelimiter = true;
      flags[m.start + 1].isDelimiter = true;
      flags[m.start].delimiterColor = const Color(0xFFCA8A04);
      flags[m.start + 1].delimiterColor = const Color(0xFFCA8A04);

      for (int i = m.start + 2; i < m.end - 2 && i < n; i++) {
        flags[i].isHighlight = true;
      }

      flags[m.end - 2].isDelimiter = true;
      flags[m.end - 1].isDelimiter = true;
      flags[m.end - 2].delimiterColor = const Color(0xFFCA8A04);
      flags[m.end - 1].delimiterColor = const Color(0xFFCA8A04);
    }

    // 2. Bold tags: <b>...</b>, <strong>...</strong>, **...**
    final bTagRegex = RegExp(r'<b>(.*?)</b>', caseSensitive: false, dotAll: true);
    for (final m in bTagRegex.allMatches(text)) {
      for (int i = m.start; i < m.start + 3 && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = m.start + 3; i < m.end - 4 && i < n; i++) {
        flags[i].isBold = true;
      }
      for (int i = m.end - 4; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final strongRegex = RegExp(r'<strong>(.*?)</strong>', caseSensitive: false, dotAll: true);
    for (final m in strongRegex.allMatches(text)) {
      for (int i = m.start; i < m.start + 8 && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = m.start + 8; i < m.end - 9 && i < n; i++) {
        flags[i].isBold = true;
      }
      for (int i = m.end - 9; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final mdBoldRegex = RegExp(r'\*\*([^\*\n]+)\*\*');
    for (final m in mdBoldRegex.allMatches(text)) {
      flags[m.start].isDelimiter = true;
      flags[m.start + 1].isDelimiter = true;
      for (int i = m.start + 2; i < m.end - 2 && i < n; i++) {
        flags[i].isBold = true;
      }
      flags[m.end - 2].isDelimiter = true;
      flags[m.end - 1].isDelimiter = true;
    }

    // 3. Italic tags: <i>...</i>, <em>...</em>, *...*
    final iTagRegex = RegExp(r'<i>(.*?)</i>', caseSensitive: false, dotAll: true);
    for (final m in iTagRegex.allMatches(text)) {
      for (int i = m.start; i < m.start + 3 && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = m.start + 3; i < m.end - 4 && i < n; i++) {
        flags[i].isItalic = true;
      }
      for (int i = m.end - 4; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final emRegex = RegExp(r'<em>(.*?)</em>', caseSensitive: false, dotAll: true);
    for (final m in emRegex.allMatches(text)) {
      for (int i = m.start; i < m.start + 4 && i < n; i++) {
        flags[i].isDelimiter = true;
      }
      for (int i = m.start + 4; i < m.end - 5 && i < n; i++) {
        flags[i].isItalic = true;
      }
      for (int i = m.end - 5; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    final mdItalicRegex = RegExp(r'(?<!\*)\*([^\*\n]+)\*(?!\*)');
    for (final m in mdItalicRegex.allMatches(text)) {
      flags[m.start].isDelimiter = true;
      for (int i = m.start + 1; i < m.end - 1 && i < n; i++) {
        flags[i].isItalic = true;
      }
      flags[m.end - 1].isDelimiter = true;
    }

    // 4. Links: <a href="...">...</a> and [label](url) and raw https://
    final htmlLinkRegex = RegExp(r'<a\s+href="([^"]*)">(.*?)</a>', caseSensitive: false, dotAll: true);
    for (final m in htmlLinkRegex.allMatches(text)) {
      final openEnd = text.indexOf('>', m.start) + 1;
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

    final mdLinkRegex = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)');
    for (final m in mdLinkRegex.allMatches(text)) {
      flags[m.start].isDelimiter = true; // [
      final closeBracket = text.indexOf(']', m.start);
      for (int i = m.start + 1; i < closeBracket && i < n; i++) {
        flags[i].isLink = true;
      }
      for (int i = closeBracket; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true; // ](url)
      }
    }

    final rawUrlRegex = RegExp(r'https?://[^\s<>"]+');
    for (final m in rawUrlRegex.allMatches(text)) {
      bool alreadyMarked = false;
      for (int i = m.start; i < m.end && i < n; i++) {
        if (flags[i].isDelimiter || flags[i].isLink) {
          alreadyMarked = true;
          break;
        }
      }
      if (!alreadyMarked) {
        for (int i = m.start; i < m.end && i < n; i++) {
          flags[i].isLink = true;
        }
      }
    }

    // 5. Center tags: <center> and </center>
    final centerRegex = RegExp(r'</?center>', caseSensitive: false);
    for (final m in centerRegex.allMatches(text)) {
      for (int i = m.start; i < m.end && i < n; i++) {
        flags[i].isDelimiter = true;
      }
    }

    // 6. Build contiguous TextSpans
    final spans = <TextSpan>[];
    int start = 0;

    while (start < n) {
      int end = start + 1;
      while (end < n && flags[end].matches(flags[start])) {
        end++;
      }

      final chunk = text.substring(start, end);
      final f = flags[start];

      TextStyle chunkStyle = baseStyle;

      if (f.isDelimiter) {
        chunkStyle = baseStyle.copyWith(
          color: (f.delimiterColor ?? baseStyle.color ?? const Color(0xFF94A3B8)).withValues(alpha: 0.45),
          fontSize: (baseStyle.fontSize ?? 14.0) * 0.82,
          fontWeight: FontWeight.normal,
          fontStyle: FontStyle.normal,
          decoration: TextDecoration.none,
          backgroundColor: Colors.transparent,
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
      }

      spans.add(TextSpan(text: chunk, style: chunkStyle));
      start = end;
    }

    return TextSpan(children: spans);
  }

  /// Completely strips all formatting tags and syntax markers, returning pure text.
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
        .replaceAll(RegExp(r'</?s>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</?del>', caseSensitive: false), '')
        .replaceAll('~~', '')
        .replaceAll(RegExp(r'</?center>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<a\s+href="[^"]*">(.*?)</a>', caseSensitive: false), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
  }

  /// Parses a single line or inline text block into styled InlineSpans for display,
  /// with ZERO raw XML/markdown tags visible and clickable links active.
  static List<InlineSpan> parseInlineSpans(
    String line,
    TextStyle baseStyle, {
    void Function(String url)? onOpenUrl,
  }) {
    if (line.isEmpty) return [TextSpan(text: '', style: baseStyle)];

    // Tokens to extract: <mark>...</mark>, ==...==, <b>...</b>, <strong>...</strong>, **...**,
    // <i>...</i>, <em>...</em>, *...*, <u>...</u>, <s>...</s>, <a href="...">...</a>, [label](url), https?://...
    final tokenRegex = RegExp(
      r'(<mark[^>]*>.*?</mark>|==[^=\n]+==|'
      r'<b>.*?</b>|<strong>.*?</strong>|\*\*[^\*\n]+\*\*|'
      r'<i>.*?</i>|<em>.*?</em>|(?<!\*)\*[^\*\n]+\*(?!\*)|'
      r'<u>.*?</u>|'
      r'<s>.*?</s>|<del>.*?</del>|~~[^~\n]+~~|'
      r'<a\s+href="([^"]*)">(.*?)</a>|'
      r'\[([^\]\n]+)\]\(([^)\n]*)\)|'
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
        final inner = matchedStr.substring(matchedStr.indexOf('>') + 1, matchedStr.length - 7);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(
            backgroundColor: highlightColor,
            color: highlightTextColor,
            fontWeight: FontWeight.w600,
          ),
          onOpenUrl: onOpenUrl,
        ));
      } else if (matchedStr.startsWith('==') && matchedStr.endsWith('==') && matchedStr.length >= 4) {
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
      } else if (matchedStr.startsWith('**') && matchedStr.endsWith('**') && matchedStr.length >= 4) {
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
      } else if (matchedStr.startsWith('*') && matchedStr.endsWith('*') && matchedStr.length >= 2) {
        final inner = matchedStr.substring(1, matchedStr.length - 1);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(fontStyle: FontStyle.italic),
          onOpenUrl: onOpenUrl,
        ));
      }
      // HTML Link <a href="...">...</a>
      else if (matchedStr.toLowerCase().startsWith('<a')) {
        final url = match.group(2) ?? '';
        final label = match.group(3) ?? url;
        spans.add(_buildClickableLinkSpan(label, url, baseStyle, onOpenUrl));
      }
      // Markdown Link [label](url)
      else if (matchedStr.startsWith('[')) {
        final label = match.group(4) ?? '';
        final url = match.group(5) ?? '';
        spans.add(_buildClickableLinkSpan(label, url, baseStyle, onOpenUrl));
      }
      // Raw URL
      else if (matchedStr.startsWith('http://') || matchedStr.startsWith('https://')) {
        spans.add(_buildClickableLinkSpan(matchedStr, matchedStr, baseStyle, onOpenUrl));
      }
      // Underline
      else if (matchedStr.toLowerCase().startsWith('<u>')) {
        final inner = matchedStr.substring(3, matchedStr.length - 4);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(decoration: TextDecoration.underline),
          onOpenUrl: onOpenUrl,
        ));
      }
      // Strikethrough
      else if (matchedStr.startsWith('~~')) {
        final inner = matchedStr.substring(2, matchedStr.length - 2);
        spans.addAll(parseInlineSpans(
          inner,
          baseStyle.copyWith(decoration: TextDecoration.lineThrough),
          onOpenUrl: onOpenUrl,
        ));
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
/// yellow highlight #FEF08A, blue clickable links #2563EB, tables, bullet/numbered lists,
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

    final baseStyle = style ??
        const TextStyle(
          fontSize: 14.0,
          color: Color(0xFF334155),
          height: 1.55,
        );

    final blocks = _parseBlocks(fullText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((b) => _renderBlock(b, baseStyle)).toList(),
    );
  }

  List<_DescriptionBlock> _parseBlocks(String text) {
    final rawLines = text.split('\n');
    final blocks = <_DescriptionBlock>[];

    int i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // 1. Table Block: lines with pipes '|' and divider
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        final tableLines = <String>[];
        while (i < rawLines.length && rawLines[i].trim().startsWith('|') && rawLines[i].trim().endsWith('|')) {
          tableLines.add(rawLines[i].trim());
          i++;
        }
        blocks.add(_DescriptionBlock(type: _BlockType.table, lines: tableLines));
        continue;
      }

      // 2. Empty spacer line
      if (trimmed.isEmpty) {
        blocks.add(_DescriptionBlock(type: _BlockType.spacer, lines: ['']));
        i++;
        continue;
      }

      // 3. Centered Block: <center>...</center>
      if (trimmed.toLowerCase().startsWith('<center>') && trimmed.toLowerCase().endsWith('</center>')) {
        final uncentered = trimmed.substring(8, trimmed.length - 9);
        blocks.add(_DescriptionBlock(type: _BlockType.center, lines: [uncentered]));
        i++;
        continue;
      }

      // 4. Bullet list item: starts with • or - or *
      final bulletMatch = RegExp(r'^\s*[-•\*]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        blocks.add(_DescriptionBlock(type: _BlockType.bullet, lines: [bulletMatch.group(1)!]));
        i++;
        continue;
      }

      // 5. Numbered list item: starts with 1. 2. etc
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

      // 6. Regular paragraph line
      blocks.add(_DescriptionBlock(type: _BlockType.paragraph, lines: [line]));
      i++;
    }

    return blocks;
  }

  Widget _renderBlock(_DescriptionBlock block, TextStyle baseStyle) {
    switch (block.type) {
      case _BlockType.spacer:
        return const SizedBox(height: 8);

      case _BlockType.center:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Center(
            child: Text.rich(
              TextSpan(
                children: RichDescriptionSyntax.parseInlineSpans(
                  block.lines.first,
                  baseStyle,
                  onOpenUrl: onOpenUrl,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 8, left: 4),
                child: Text('•', style: TextStyle(color: Color(0xFF2563EB), fontSize: 16, fontWeight: FontWeight.bold)),
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
                child: Text('$numLabel.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5, fontWeight: FontWeight.bold)),
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

      // Skip markdown separator row like | :--- | :--- |
      final isSeparator = parts.every((p) => RegExp(r'^:?-+:?$').hasMatch(p));
      if (!isSeparator && parts.isNotEmpty) {
        parsedRows.add(parts);
      }
    }

    if (parsedRows.isEmpty) return const SizedBox.shrink();

    final maxCols = parsedRows.map((r) => r.length).reduce(max);
    final headerRow = parsedRows.first;
    final bodyRows = parsedRows.length > 1 ? parsedRows.sublist(1) : <List<String>>[];

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
        border: const TableBorder(
          horizontalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
          verticalInside: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Header Row
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC)),
            children: List.generate(maxCols, (colIdx) {
              final cellText = colIdx < headerRow.length ? headerRow[colIdx] : '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                alignment: Alignment.centerLeft,
                child: Text(
                  cellText,
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                    fontSize: (baseStyle.fontSize ?? 14.0) * 0.95,
                  ),
                ),
              );
            }),
          ),
          // Body Rows
          ...bodyRows.map((row) {
            return TableRow(
              children: List.generate(maxCols, (colIdx) {
                final cellText = colIdx < row.length ? row[colIdx] : '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: RichDescriptionSyntax.parseInlineSpans(
                        cellText,
                        baseStyle.copyWith(fontSize: (baseStyle.fontSize ?? 14.0) * 0.95),
                        onOpenUrl: onOpenUrl,
                      ),
                    ),
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

enum _BlockType { paragraph, bullet, numbered, center, table, spacer }

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

/// Rich Description Editor box with toolbar matching the TravChad / Lucide design.
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
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller is RichTextEditingController) {
      _effectiveController = widget.controller as RichTextEditingController;
      _ownsController = false;
    } else {
      _effectiveController = RichTextEditingController(text: widget.controller.text);
      _effectiveController.selection = widget.controller.selection;
      _ownsController = true;
      _effectiveController.addListener(_syncToWidgetController);
      widget.controller.addListener(_syncFromWidgetController);
    }

    _pushHistory(_effectiveController.value);
    _effectiveController.addListener(_onTextChanged);
  }

  void _syncToWidgetController() {
    if (widget.controller.value != _effectiveController.value) {
      widget.controller.value = _effectiveController.value;
    }
  }

  void _syncFromWidgetController() {
    if (_effectiveController.value != widget.controller.value) {
      _effectiveController.value = widget.controller.value;
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_onTextChanged);
    if (_ownsController) {
      _effectiveController.removeListener(_syncToWidgetController);
      widget.controller.removeListener(_syncFromWidgetController);
      _effectiveController.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isPerformingUndoRedo) return;
    if (_history.isEmpty || _history[_historyIndex].text != _effectiveController.text) {
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
  bool get _canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

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

  // --- Formatting Helpers ---
  void _toggleWrap(
    String prefix,
    String suffix, {
    List<String> alternativePrefixes = const [],
    List<String> alternativeSuffixes = const [],
  }) {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);

      // Check primary or alternative wrapping to unwrap
      bool unwrapped = false;
      final allPrefixes = [prefix, ...alternativePrefixes];
      final allSuffixes = [suffix, ...alternativeSuffixes];

      for (int i = 0; i < allPrefixes.length; i++) {
        final p = allPrefixes[i];
        final s = i < allSuffixes.length ? allSuffixes[i] : suffix;

        if (selectedText.startsWith(p) && selectedText.endsWith(s) && selectedText.length >= p.length + s.length) {
          final innerText = selectedText.substring(p.length, selectedText.length - s.length);
          final newText = text.replaceRange(selection.start, selection.end, innerText);
          _effectiveController.value = TextEditingValue(
            text: newText,
            selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + innerText.length),
          );
          unwrapped = true;
          break;
        }
      }

      if (!unwrapped) {
        // Wrap with primary tags
        final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
        _effectiveController.value = TextEditingValue(
          text: newText,
          selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + prefix.length + selectedText.length + suffix.length),
        );
      }
    }
    _focusNode.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith(prefix)) {
      final updatedLine = currentLine.substring(prefix.length);
      final newText = text.replaceRange(lineStart, effectiveEnd, updatedLine);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: max(lineStart, cursor - prefix.length)),
      );
    } else {
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _toggleNumberedList() {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    final match = RegExp(r'^\d+\.\s+').firstMatch(currentLine);
    if (match != null) {
      final updatedLine = currentLine.substring(match.end);
      final newText = text.replaceRange(lineStart, effectiveEnd, updatedLine);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: max(lineStart, cursor - match.end)),
      );
    } else {
      const prefix = '1. ';
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _toggleCenterAlign() {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith('<center>') && currentLine.endsWith('</center>')) {
      final uncentered = currentLine.substring(8, currentLine.length - 9);
      final newText = text.replaceRange(lineStart, effectiveEnd, uncentered);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + uncentered.length),
      );
    } else {
      final centered = '<center>$currentLine</center>';
      final newText = text.replaceRange(lineStart, effectiveEnd, centered);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + centered.length - 9),
      );
    }
    _focusNode.requestFocus();
  }

  void _alignLeft() {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith('<center>') && currentLine.endsWith('</center>')) {
      final uncentered = currentLine.substring(8, currentLine.length - 9);
      final newText = text.replaceRange(lineStart, effectiveEnd, uncentered);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + uncentered.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _clearFormatting() {
    final text = _effectiveController.text;
    final selection = _effectiveController.selection;

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

      final newText = text.replaceRange(selection.start, selection.end, cleaned);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + cleaned.length),
      );
    }
    _focusNode.requestFocus();
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
            Text('Insert Link', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                  hintText: 'e.g. Airline Ticket Portal',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: 'Web URL',
                  hintText: 'https://...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final label = linkTextCtrl.text.trim().isEmpty ? 'Link' : linkTextCtrl.text.trim();
              final url = urlCtrl.text.trim().isEmpty ? 'https://' : urlCtrl.text.trim();
              final mdLink = '[$label]($url)';

              final text = _effectiveController.text;
              if (selection.isValid && !selection.isCollapsed) {
                final newText = text.replaceRange(selection.start, selection.end, mdLink);
                _effectiveController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: selection.start + mdLink.length),
                );
              } else {
                final offset = selection.isValid ? selection.start : text.length;
                final newText = text.replaceRange(offset, offset, mdLink);
                _effectiveController.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: offset + mdLink.length),
                );
              }
              _focusNode.requestFocus();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: const Text('Insert Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInsertTableDialog() {
    int rows = 3;
    int cols = 3;

    void insert(int r, int c) {
      String tableMd = '\n|';
      for (int i = 1; i <= c; i++) {
        tableMd += ' Header $i |';
      }
      tableMd += '\n|';
      for (int i = 1; i <= c; i++) {
        tableMd += ' :--- |';
      }
      for (int j = 1; j <= r; j++) {
        tableMd += '\n|';
        for (int i = 1; i <= c; i++) {
          tableMd += ' Cell $j-$i |';
        }
      }
      tableMd += '\n\n';

      final text = _effectiveController.text;
      final selection = _effectiveController.selection;
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, tableMd);
      _effectiveController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + tableMd.length),
      );
      _focusNode.requestFocus();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              CustomPaint(size: Size(18, 18), painter: TableGridPainter(color: Color(0xFF2563EB))),
              SizedBox(width: 10),
              Text('Insert Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Presets:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          insert(2, 2);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('2 × 2', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          insert(3, 3);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('3 × 3', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          insert(4, 2);
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        child: const Text('4 × 2', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rows', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: '$rows',
                            keyboardType: TextInputType.number,
                            onChanged: (v) => rows = max(1, int.tryParse(v) ?? 1),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Columns', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextFormField(
                            initialValue: '$cols',
                            keyboardType: TextInputType.number,
                            onChanged: (v) => cols = max(1, int.tryParse(v) ?? 1),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                insert(rows, cols);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: const Text('Insert Table', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFullscreen() {
    if (widget.isFullscreen) {
      if (widget.onExitFullscreen != null) {
        widget.onExitFullscreen!();
      } else {
        Navigator.pop(context);
      }
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Description Editor (Fullscreen)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                    controller: _effectiveController,
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
  }) {
    final activeColor = enabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(6),
          hoverColor: const Color(0xFFF1F5F9),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: customWidget ??
                (text != null
                    ? Text(
                        text,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: text == 'B' ? FontWeight.w800 : FontWeight.w600,
                          fontStyle: text == 'I' ? FontStyle.italic : FontStyle.normal,
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  onPressed: () => _toggleWrap('**', '**', alternativePrefixes: ['<b>'], alternativeSuffixes: ['</b>']),
                ),
                _buildIconButton(
                  text: 'I',
                  tooltip: 'Italic (Ctrl+I)',
                  onPressed: () => _toggleWrap('*', '*', alternativePrefixes: ['<i>'], alternativeSuffixes: ['</i>']),
                ),
                _buildIconButton(
                  customWidget: const CustomPaint(
                    size: Size(16, 16),
                    painter: PenLinePainter(color: Color(0xFF475569)),
                  ),
                  tooltip: 'Highlight Text (<mark>)',
                  onPressed: () => _toggleWrap('<mark>', '</mark>', alternativePrefixes: ['=='], alternativeSuffixes: ['==']),
                ),
                _buildIconButton(
                  icon: Icons.link_rounded,
                  tooltip: 'Insert Link',
                  onPressed: _showInsertLinkDialog,
                ),

                _buildDivider(),

                // Group 2: Bullet List, Numbered List, Align Center, Align Left, Table
                _buildIconButton(
                  icon: Icons.format_list_bulleted_rounded,
                  tooltip: 'Bulleted List',
                  onPressed: () => _toggleLinePrefix('- '),
                ),
                _buildIconButton(
                  icon: Icons.format_list_numbered_rounded,
                  tooltip: 'Numbered List',
                  onPressed: _toggleNumberedList,
                ),
                _buildIconButton(
                  icon: Icons.format_align_center_rounded,
                  tooltip: 'Align Center',
                  onPressed: _toggleCenterAlign,
                ),
                _buildIconButton(
                  icon: Icons.format_align_left_rounded,
                  tooltip: 'Align Left',
                  onPressed: _alignLeft,
                ),
                _buildIconButton(
                  customWidget: const CustomPaint(
                    size: Size(16, 16),
                    painter: TableGridPainter(color: Color(0xFF475569)),
                  ),
                  tooltip: 'Insert Table',
                  onPressed: _showInsertTableDialog,
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
                  tooltip: 'Undo',
                  enabled: _canUndo,
                  onPressed: _canUndo ? _undo : null,
                ),
                _buildIconButton(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: _canRedo,
                  onPressed: _canRedo ? _redo : null,
                ),

                _buildDivider(),

                // Group 5: Fullscreen / Maximize
                _buildIconButton(
                  icon: widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.crop_free_rounded,
                  tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Fullscreen',
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
          ),

          // Editable Canvas
          Expanded(
            flex: widget.isFullscreen ? 1 : 0,
            child: TextField(
              controller: _effectiveController,
              focusNode: _focusNode,
              minLines: widget.isFullscreen ? 18 : widget.minLines,
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
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
