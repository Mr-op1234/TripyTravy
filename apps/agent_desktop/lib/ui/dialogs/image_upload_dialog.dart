import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/itinerary_database.dart';

/// Small modal dialog for uploading event images & GIFs.
/// Clicking the upload area opens the file picker.
/// Pressing Ctrl + V pastes images from clipboard while this dialog is active.
class ImageUploadDialog extends StatefulWidget {
  final List<String> currentPhotos;
  final ValueChanged<String> onImageAdded;
  final ValueChanged<String>? onImageRemoved;

  static const List<String> supportedExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
  ];

  const ImageUploadDialog({
    super.key,
    this.currentPhotos = const [],
    required this.onImageAdded,
    this.onImageRemoved,
  });

  @override
  ImageUploadDialogState createState() => ImageUploadDialogState();
}

class ImageUploadDialogState extends State<ImageUploadDialog> {
  final FocusNode _focusNode = FocusNode();
  final List<String> _sessionAddedPhotos = [];
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = true;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        HardwareKeyboard.instance.isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyV) {
      pasteFromClipboard();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> pasteFromClipboard() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      // 1. Check raw image bytes on clipboard (e.g. screenshot, snipping tool, copied browser image)
      final imageBytes = await Pasteboard.image.timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => null,
      );
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final appSupportDir = await getApplicationSupportDirectory();
        final photosDir =
            Directory(p.join(appSupportDir.path, 'TripyTravy', 'event_photos'));
        if (!await photosDir.exists()) {
          await photosDir.create(recursive: true);
        }
        final fileName =
            'pasted_${DateTime.now().millisecondsSinceEpoch}_${imageBytes.length.hashCode.abs()}.png';
        final savedFile = File(p.join(photosDir.path, fileName));
        await savedFile.writeAsBytes(imageBytes);

        final path = savedFile.path;
        widget.onImageAdded(path);
        if (mounted) {
          setState(() {
            _sessionAddedPhotos.add(path);
            _statusMessage = 'Image pasted successfully!';
            _isSuccess = true;
          });
        }
        return;
      }

      // 2. Check files on clipboard (e.g. copied image/gif files in Windows Explorer)
      final files = await Pasteboard.files().timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => <String>[],
      );
      if (files.isNotEmpty) {
        final added = <String>[];
        for (final filePath in files) {
          final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();
          if (ImageUploadDialog.supportedExtensions.contains(ext)) {
            final saved =
                await ItineraryDatabase.saveEventPhotoToAppStorage(filePath);
            if (!_sessionAddedPhotos.contains(saved)) {
              widget.onImageAdded(saved);
              added.add(saved);
            }
          }
        }
        if (added.isNotEmpty && mounted) {
          setState(() {
            _sessionAddedPhotos.addAll(added);
            _statusMessage = 'Pasted ${added.length} image(s)!';
            _isSuccess = true;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _statusMessage = 'No image or GIF found in clipboard to paste';
          _isSuccess = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Paste error: $e';
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _pickFromFolder() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ImageUploadDialog.supportedExtensions,
        dialogTitle: 'Select Images & GIFs to Add',
      );
      if (files.isNotEmpty) {
        final added = <String>[];
        for (final f in files) {
          final path = f.path;
          if (path != null && path.isNotEmpty) {
            final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
            if (ImageUploadDialog.supportedExtensions.contains(ext)) {
              final saved =
                  await ItineraryDatabase.saveEventPhotoToAppStorage(path);
              if (!_sessionAddedPhotos.contains(saved)) {
                widget.onImageAdded(saved);
                added.add(saved);
              }
            }
          }
        }
        if (added.isNotEmpty && mounted) {
          setState(() {
            _sessionAddedPhotos.addAll(added);
            _statusMessage = 'Added ${added.length} file(s) from folder!';
            _isSuccess = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Could not open folder: $e';
          _isSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            pasteFromClipboard,
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded,
                        color: Color(0xFF2563EB), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Upload Images & GIFs',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF64748B)),
                    splashRadius: 18,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Upload / Drop zone card
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: GestureDetector(
                  onTap: _pickFromFolder,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? const Color(0xFFEFF6FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isHovered
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFBFDBFE),
                        width: _isHovered ? 2.0 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _isHovered
                                ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                                : const Color(0xFF2563EB).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 28,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Click to open folder to upload images or directly paste here',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'PNG, JPG, JPEG, WEBP, GIF • Press Ctrl + V to paste',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.content_paste_rounded,
                                  size: 13, color: Color(0xFF475569)),
                              SizedBox(width: 5),
                              Text(
                                'Ctrl + V enabled',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isProcessing) ...[
                const SizedBox(height: 14),
                const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],

              if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isSuccess
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isSuccess
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 16,
                        color: _isSuccess
                            ? const Color(0xFF059669)
                            : const Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: _isSuccess
                                ? const Color(0xFF065F46)
                                : const Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_sessionAddedPhotos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Added (${_sessionAddedPhotos.length}):',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sessionAddedPhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final photoPath = _sessionAddedPhotos[idx];
                      final file = File(photoPath);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              color: const Color(0xFFF1F5F9),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: file.existsSync()
                                ? Image.file(file, fit: BoxFit.cover)
                                : const Icon(Icons.image,
                                    color: Color(0xFF94A3B8)),
                          ),
                          Positioned(
                            top: -4,
                            right: -4,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _sessionAddedPhotos.removeAt(idx);
                                });
                                widget.onImageRemoved?.call(photoPath);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F172A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 10),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
