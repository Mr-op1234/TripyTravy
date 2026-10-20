import 'dart:math';
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

  @override
  void initState() {
    super.initState();
    _pushHistory(widget.controller.value);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_isPerformingUndoRedo) return;
    if (_history.isEmpty || _history[_historyIndex].text != widget.controller.text) {
      _pushHistory(widget.controller.value);
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
    widget.controller.value = _history[_historyIndex];
    _isPerformingUndoRedo = false;
    setState(() {});
  }

  void _redo() {
    if (!_canRedo) return;
    _isPerformingUndoRedo = true;
    _historyIndex++;
    widget.controller.value = _history[_historyIndex];
    _isPerformingUndoRedo = false;
    setState(() {});
  }

  // --- Formatting Helpers ---
  void _toggleWrap(String prefix, String suffix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, '$prefix$suffix');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + prefix.length),
      );
    } else {
      final selectedText = selection.textInside(text);
      if (selectedText.startsWith(prefix) && selectedText.endsWith(suffix) && selectedText.length >= prefix.length + suffix.length) {
        // Unwrap
        final innerText = selectedText.substring(prefix.length, selectedText.length - suffix.length);
        final newText = text.replaceRange(selection.start, selection.end, innerText);
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + innerText.length),
        );
      } else {
        // Wrap
        final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + prefix.length + selectedText.length + suffix.length),
        );
      }
    }
    _focusNode.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith(prefix)) {
      // Remove prefix
      final updatedLine = currentLine.substring(prefix.length);
      final newText = text.replaceRange(lineStart, effectiveEnd, updatedLine);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: max(lineStart, cursor - prefix.length)),
      );
    } else {
      // Add prefix
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _toggleNumberedList() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    final match = RegExp(r'^\d+\.\s+').firstMatch(currentLine);
    if (match != null) {
      final updatedLine = currentLine.substring(match.end);
      final newText = text.replaceRange(lineStart, effectiveEnd, updatedLine);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: max(lineStart, cursor - match.end)),
      );
    } else {
      const prefix = '1. ';
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _toggleCenterAlign() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith('<center>') && currentLine.endsWith('</center>')) {
      final uncentered = currentLine.substring(8, currentLine.length - 9);
      final newText = text.replaceRange(lineStart, effectiveEnd, uncentered);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + uncentered.length),
      );
    } else {
      final centered = '<center>$currentLine</center>';
      final newText = text.replaceRange(lineStart, effectiveEnd, centered);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + centered.length - 9),
      );
    }
    _focusNode.requestFocus();
  }

  void _alignLeft() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final cursor = selection.isValid ? selection.start : text.length;

    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineEnd = text.indexOf('\n', cursor);
    final effectiveEnd = lineEnd == -1 ? text.length : lineEnd;
    final currentLine = text.substring(lineStart, effectiveEnd);

    if (currentLine.startsWith('<center>') && currentLine.endsWith('</center>')) {
      final uncentered = currentLine.substring(8, currentLine.length - 9);
      final newText = text.replaceRange(lineStart, effectiveEnd, uncentered);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart + uncentered.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _clearFormatting() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;

    if (!selection.isValid || selection.isCollapsed) {
      // Clear formatting across whole text
      String cleaned = text
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('~~', '')
          .replaceAll('<mark>', '')
          .replaceAll('</mark>', '')
          .replaceAll('<center>', '')
          .replaceAll('</center>', '')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
          .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

      widget.controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    } else {
      final selectedText = selection.textInside(text);
      String cleaned = selectedText
          .replaceAll('**', '')
          .replaceAll('*', '')
          .replaceAll('~~', '')
          .replaceAll('<mark>', '')
          .replaceAll('</mark>', '')
          .replaceAll('<center>', '')
          .replaceAll('</center>', '')
          .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
          .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '')
          .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

      final newText = text.replaceRange(selection.start, selection.end, cleaned);
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(baseOffset: selection.start, extentOffset: selection.start + cleaned.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _showInsertLinkDialog() {
    final linkTextCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final selection = widget.controller.selection;
    if (selection.isValid && !selection.isCollapsed) {
      linkTextCtrl.text = selection.textInside(widget.controller.text);
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

              final text = widget.controller.text;
              if (selection.isValid && !selection.isCollapsed) {
                final newText = text.replaceRange(selection.start, selection.end, mdLink);
                widget.controller.value = TextEditingValue(
                  text: newText,
                  selection: TextSelection.collapsed(offset: selection.start + mdLink.length),
                );
              } else {
                final offset = selection.isValid ? selection.start : text.length;
                final newText = text.replaceRange(offset, offset, mdLink);
                widget.controller.value = TextEditingValue(
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

      final text = widget.controller.text;
      final selection = widget.controller.selection;
      final offset = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(offset, offset, tableMd);
      widget.controller.value = TextEditingValue(
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
                  onPressed: () => _toggleWrap('**', '**'),
                ),
                _buildIconButton(
                  text: 'I',
                  tooltip: 'Italic (Ctrl+I)',
                  onPressed: () => _toggleWrap('*', '*'),
                ),
                _buildIconButton(
                  customWidget: const CustomPaint(
                    size: Size(16, 16),
                    painter: PenLinePainter(color: Color(0xFF475569)),
                  ),
                  tooltip: 'Highlight Text (<mark>)',
                  onPressed: () => _toggleWrap('<mark>', '</mark>'),
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
              controller: widget.controller,
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
