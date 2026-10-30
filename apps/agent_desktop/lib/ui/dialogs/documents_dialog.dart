import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../../data/itinerary_database.dart';
import '../../data/google_maps_helper.dart';
import '../widgets/rich_description_editor.dart';

/// Reusable modal dialog for renaming files across Agent Desktop
Future<String?> showRenameFileDialog({
  required BuildContext context,
  required String currentName,
  String title = 'Rename File',
}) async {
  final controller = TextEditingController(text: currentName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter a new name for this file:',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Flight_Ticket.pdf',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                var res = val.trim();
                final ext = p.extension(currentName);
                if (p.extension(res).isEmpty && ext.isNotEmpty) {
                  res = '$res$ext';
                }
                Navigator.pop(ctx, res);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          onPressed: () {
            final val = controller.text.trim();
            if (val.isNotEmpty) {
              var res = val;
              final ext = p.extension(currentName);
              if (p.extension(res).isEmpty && ext.isNotEmpty) {
                res = '$res$ext';
              }
              Navigator.pop(ctx, res);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}

class DocumentsManagerDialog extends StatefulWidget {
  final int itineraryId;
  final String tripTitle;
  final List<TripEventItem> availableEvents;
  final List<TripDocumentItem>? initialDocuments;

  const DocumentsManagerDialog({
    super.key,
    required this.itineraryId,
    required this.tripTitle,
    this.availableEvents = const [],
    this.initialDocuments,
  });

  @override
  State<DocumentsManagerDialog> createState() => _DocumentsManagerDialogState();
}

class _DocumentsManagerDialogState extends State<DocumentsManagerDialog> {
  List<TripDocumentItem> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialDocuments != null) {
      _documents = List.from(widget.initialDocuments!);
      _isLoading = false;
    } else {
      _loadDocuments();
    }
  }

  Future<void> _loadDocuments() async {
    final docs = await ItineraryDatabase.instance.getDocumentsForItinerary(widget.itineraryId);
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  void _openFile(String path) {
    if (path.isEmpty) return;
    try {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        if (Platform.isWindows) {
          Process.run('explorer.exe', [path]);
        } else {
          Process.run('open', [path]);
        }
        return;
      }
      final f = File(path);
      if (f.existsSync()) {
        if (Platform.isWindows) {
          Process.run('explorer.exe', [path]);
        } else {
          Process.run('open', [path]);
        }
      }
    } catch (_) {}
  }

  Future<void> _deleteDoc(TripDocumentItem doc) async {
    await ItineraryDatabase.instance.deleteDocument(doc.id);
    _loadDocuments();
  }

  void _showAddInformationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddInformationDialog(
        itineraryId: widget.itineraryId,
        availableEvents: widget.availableEvents,
        onDocumentSaved: () {
          _loadDocuments();
        },
      ),
    );
  }

  void _showEditInformationDialog(TripDocumentItem doc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddInformationDialog(
        itineraryId: widget.itineraryId,
        availableEvents: widget.availableEvents,
        itemToEdit: doc,
        onDocumentSaved: () {
          _loadDocuments();
        },
      ),
    );
  }

  String _getFriendlyFileType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF Document';
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return 'Image';
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'Word Document';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) return 'Spreadsheet';
    if (lower.endsWith('.txt')) return 'Text Document';
    return 'Document';
  }

  Widget _buildRichDescription(String rawText, {String? mapUrl}) {
    return RichDescriptionView(
      description: rawText,
      mapUrl: mapUrl,
      onOpenUrl: _openFile,
      style: const TextStyle(
        fontSize: 14.5,
        color: Color(0xFF334155),
        height: 1.55,
      ),
    );
  }

  Future<void> _renameDocumentAttachment(TripDocumentItem doc, String currentName) async {
    final newName = await showRenameFileDialog(
      context: context,
      currentName: currentName,
    );
    if (newName != null && newName.trim().isNotEmpty && newName.trim() != currentName) {
      await ItineraryDatabase.instance.renameTripDocument(
        doc.id,
        newName.trim(),
        targetAttachmentName: currentName,
      );
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed file to "$newName"')),
        );
      }
    }
  }

  Widget _buildAttachmentPill(Map<String, String> att, TripDocumentItem doc) {
    final name = att['name'] ?? 'Document';
    final size = att['size'] ?? '';
    final path = att['path'] ?? '';
    final typeStr = _getFriendlyFileType(name);
    final subtitle = size.isNotEmpty ? '$typeStr · $size' : typeStr;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openFile(path),
          hoverColor: const Color(0xFF2563EB).withValues(alpha: 0.04),
          splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
          child: Row(
            children: [
              Container(
                width: 58,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(13)),
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -0.7,
                    child: const Icon(
                      Icons.attach_file_rounded,
                      size: 24,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Rename File',
                onPressed: () => _renameDocumentAttachment(doc, name),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: Color(0xFF64748B),
                ),
                splashRadius: 18,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInformationCard(TripDocumentItem doc) {
    final hasAttachments = doc.attachments.isNotEmpty || (doc.fileName.isNotEmpty && doc.filePath.isNotEmpty);
    final List<Map<String, String>> attachmentsList = doc.attachments.isNotEmpty
        ? doc.attachments
        : (doc.fileName.isNotEmpty && doc.filePath.isNotEmpty
            ? [{'name': doc.fileName, 'size': doc.fileSize, 'path': doc.filePath}]
            : []);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: 6-dot drag indicator, Blue Info Badge, Title, Edit button, 3-dots menu
          Row(
            children: [
              const Icon(
                Icons.drag_indicator_rounded,
                color: Color(0xFFCBD5E1),
                size: 20,
              ),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  doc.title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Edit Information',
                onPressed: () => _showEditInformationDialog(doc),
                icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF64748B)),
                splashRadius: 18,
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Color(0xFF64748B)),
                splashRadius: 18,
                onSelected: (val) {
                  if (val == 'edit') _showEditInformationDialog(doc);
                  if (val == 'delete') _deleteDoc(doc);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Edit Information', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Delete Information', style: TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Description & Clickable Links
          if (doc.description.isNotEmpty || (doc.mapUrl != null && doc.mapUrl!.isNotEmpty)) ...[
            const SizedBox(height: 14),
            _buildRichDescription(
              doc.description,
              mapUrl: doc.mapUrl,
            ),
          ],

          // Attachment Pills (Image 1 style)
          if (hasAttachments) ...[
            const SizedBox(height: 16),
            Column(
              children: attachmentsList.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildAttachmentPill(att, doc),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = screenSize.width * 0.92;
    final dialogHeight = screenSize.height * 0.90;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Documents & Information',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stored passes, vouchers, and bookings for ${widget.tripTitle}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 22),
                  tooltip: 'Close (Esc)',
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Document / Information List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Icon(Icons.file_copy_outlined, size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'No documents or information attached yet',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Attach flight tickets, hotel vouchers, location maps, or trip guidelines.',
                                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: _documents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildInformationCard(_documents[index]);
                          },
                        ),
            ),
            const SizedBox(height: 18),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddInformationDialog,
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AddInformationDialog extends StatefulWidget {
  final int itineraryId;
  final List<TripEventItem> availableEvents;
  final TripDocumentItem? itemToEdit;
  final VoidCallback onDocumentSaved;

  const AddInformationDialog({
    super.key,
    required this.itineraryId,
    this.availableEvents = const [],
    this.itemToEdit,
    required this.onDocumentSaved,
  });

  @override
  State<AddInformationDialog> createState() => _AddInformationDialogState();
}

class _AddInformationDialogState extends State<AddInformationDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapsUrlController = TextEditingController();

  final List<PlatformFile> _attachedFiles = [];
  final Map<int, String> _customPickedNames = {};
  List<Map<String, String>> _existingAttachments = [];
  GoogleMapsLocation? _fetchedLocation;
  bool _isFetchingLocation = false;
  String? _locationStatusMessage;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final doc = widget.itemToEdit!;
      _titleController.text = doc.title;
      _descriptionController.text = doc.description;
      if (doc.hasLocation) {
        _mapsUrlController.text = doc.mapUrl ?? '';
        _fetchedLocation = GoogleMapsLocation(
          rawUrl: doc.mapUrl ?? '',
          locationName: doc.locationName ?? '',
          latitude: doc.latitude,
          longitude: doc.longitude,
        );
      }
      _existingAttachments = List.from(doc.attachments);
      if (_existingAttachments.isEmpty && doc.filePath.isNotEmpty) {
        _existingAttachments.add({
          'name': doc.fileName,
          'size': doc.fileSize,
          'path': doc.filePath,
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _mapsUrlController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }


  int _getFileSizeBytes(PlatformFile f) {
    final syncLen = f.lengthSync();
    if (syncLen != null) return syncLen;
    if (f.path != null && File(f.path!).existsSync()) {
      try {
        return File(f.path!).lengthSync();
      } catch (_) {}
    }
    return 0;
  }

  // --- Attach Documents Section ---
  Future<void> _pickFiles() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Documents to Attach',
      );
      if (files.isNotEmpty) {
        setState(() {
          for (final f in files) {
            if (!_attachedFiles.any((existing) => existing.path == f.path)) {
              _attachedFiles.add(f);
            }
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not select files: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
      _customPickedNames.remove(index);
    });
  }

  Future<void> _renameExistingAttachment(int index) async {
    final current = _existingAttachments[index];
    final currentName = current['name'] ?? 'File';
    final newName = await showRenameFileDialog(
      context: context,
      currentName: currentName,
    );
    if (newName != null && newName.trim().isNotEmpty && newName.trim() != currentName) {
      final sanitizedName = newName.trim();
      final path = current['path'];
      String updatedPath = path ?? '';
      if (path != null && path.isNotEmpty) {
        updatedPath = await ItineraryDatabase.renameDocumentFile(path, sanitizedName);
      }
      setState(() {
        _existingAttachments[index] = {
          ...current,
          'name': sanitizedName,
          'path': updatedPath,
        };
      });
    }
  }

  Future<void> _renamePickedFile(int index) async {
    final f = _attachedFiles[index];
    final currentName = _customPickedNames[index] ?? f.name;
    final newName = await showRenameFileDialog(
      context: context,
      currentName: currentName,
    );
    if (newName != null && newName.trim().isNotEmpty && newName.trim() != currentName) {
      setState(() {
        _customPickedNames[index] = newName.trim();
      });
    }
  }

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return Icons.description_rounded;
    }
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  // --- Location Card Actions ---
  void _onMapsUrlChanged(String val) {
    _debounceTimer?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _fetchedLocation = null;
        _locationStatusMessage = null;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 450), () {
      _fetchLocationData(val);
    });
  }

  Future<void> _fetchLocationData(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return;

    setState(() {
      _isFetchingLocation = true;
      _locationStatusMessage = 'Fetching location details and coordinates...';
    });

    try {
      final location = await GoogleMapsHelper.parse(url);
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          if (location != null) {
            _fetchedLocation = location;
            _locationStatusMessage = null;
            if (_titleController.text.trim().isEmpty) {
              _titleController.text = location.locationName;
            }
          } else {
            _locationStatusMessage = 'Could not extract location data from link. Please check the URL.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
          _locationStatusMessage = 'Error fetching location: $e';
        });
      }
    }
  }

  void _openLocationInBrowser(String url) {
    if (url.isEmpty) return;
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [url]);
      } else {
        Process.run('open', [url]);
      }
    } catch (_) {}
  }

  bool _isSaving = false;

  // --- Save ---
  Future<void> _save() async {
    if (_isSaving) return;

    var title = _titleController.text.trim();
    if (title.isEmpty) {
      if (_fetchedLocation != null && _fetchedLocation!.locationName.trim().isNotEmpty) {
        title = _fetchedLocation!.locationName.trim();
      } else if (_attachedFiles.isNotEmpty) {
        title = _attachedFiles.first.name;
      } else if (_descriptionController.text.trim().isNotEmpty) {
        final firstLine = _descriptionController.text.trim().split('\n').first.trim();
        title = firstLine.length > 50 ? '${firstLine.substring(0, 50)}...' : firstLine;
      } else {
        title = 'Trip Information';
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, String>> savedAttachments = List.from(_existingAttachments);
      for (var i = 0; i < _attachedFiles.length; i++) {
        final f = _attachedFiles[i];
        if (f.path != null) {
          final customName = _customPickedNames[i] ?? f.name;
          final savedPath = await ItineraryDatabase.saveDocumentToAppStorage(
            f.path!,
            customFileName: customName,
          );
          final sizeBytes = _getFileSizeBytes(f);
          final sizeKb = sizeBytes / 1024;
          final sizeStr = sizeKb > 1024
              ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
              : '${sizeKb.toStringAsFixed(1)} KB';
          savedAttachments.add({
            'name': customName,
            'size': sizeStr,
            'path': savedPath,
          });
        }
      }

      final primary = savedAttachments.isNotEmpty ? savedAttachments.first : null;

      final docItem = TripDocumentItem(
        id: widget.itemToEdit?.id ?? 'info_${DateTime.now().millisecondsSinceEpoch}',
        itineraryId: widget.itineraryId,
        eventId: widget.itemToEdit?.eventId ?? (widget.availableEvents.isNotEmpty ? widget.availableEvents.first.id : null),
        docType: _fetchedLocation != null ? 'location' : 'info',
        title: title,
        description: _descriptionController.text.trim(),
        fileName: primary != null ? primary['name']! : (_fetchedLocation != null ? 'Location' : 'Information'),
        fileSize: primary != null ? primary['size']! : '',
        filePath: primary != null ? primary['path']! : '',
        colorScheme: _fetchedLocation != null ? 'blue' : 'emerald',
        locationName: _fetchedLocation?.locationName,
        latitude: _fetchedLocation?.latitude,
        longitude: _fetchedLocation?.longitude,
        mapUrl: _fetchedLocation?.rawUrl,
        attachmentsJson: savedAttachments.isNotEmpty ? jsonEncode(savedAttachments) : null,
      );

      if (widget.itemToEdit != null) {
        await ItineraryDatabase.instance.updateDocument(docItem);
      } else {
        await ItineraryDatabase.instance.insertDocument(docItem);
      }
      widget.onDocumentSaved();
      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Error saving information: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not save: $e';
          _isSaving = false;
        });
      }
    }
  }


  // --- Location Card Widget ---
  Widget _buildLocationCard(GoogleMapsLocation loc) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.locationName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                if (loc.coordinatesDisplay.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded, size: 12, color: Color(0xFF0284C7)),
                      const SizedBox(width: 4),
                      Text(
                        loc.coordinatesDisplay,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Open in Maps Browser',
            onPressed: () => _openLocationInBrowser(loc.rawUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
            splashRadius: 18,
          ),
          IconButton(
            tooltip: 'Remove Location',
            onPressed: () {
              setState(() {
                _fetchedLocation = null;
                _mapsUrlController.clear();
                _locationStatusMessage = null;
              });
            },
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final dialogWidth = (screenSize.width * 0.88).clamp(680.0, 1050.0);
    final dialogHeight = (screenSize.height * 0.88).clamp(600.0, 880.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemToEdit != null ? 'Edit Information' : 'Add Information',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        widget.itemToEdit != null
                            ? 'Update details, coordinates, or attached documents'
                            : 'Add trip guidelines, location coordinates, and attach documents',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Scrollable Form Body
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Information Title (as shown in image)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text(
                            'Title *',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B)),
                            decoration: InputDecoration(
                              hintText: 'e.g. Flight booking confirmation',
                              hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 2. Information Description (Rich Editor as shown in image)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: 140,
                            child: Text(
                              'Description',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RichDescriptionEditor(
                            controller: _descriptionController,
                            placeholder: 'Write description here...',
                            minLines: 5,
                            maxLines: 9,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 3. Attach Documents Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Attach Documents',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            Text(
                              'Upload vouchers, tickets, passes, PDFs, or photos',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.attach_file_rounded, size: 16),
                          label: const Text('Browse Files to Attach', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Attached Files List
                    if (_attachedFiles.isEmpty && _existingAttachments.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.attachment_rounded, size: 18, color: Color(0xFF94A3B8)),
                            SizedBox(width: 8),
                            Text('No documents attached yet (optional)', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            // Existing attachments
                            ..._existingAttachments.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final att = entry.value;
                              final name = att['name'] ?? '';
                              final size = att['size'] ?? '';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_getFileIcon(name), size: 18, color: const Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        size.isNotEmpty ? '$name ($size)' : name,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                      onPressed: () => _renameExistingAttachment(idx),
                                      splashRadius: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      tooltip: 'Rename File',
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () {
                                        setState(() {
                                          _existingAttachments.removeAt(idx);
                                        });
                                      },
                                      splashRadius: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              );
                            }),
                            // Newly picked files
                            ..._attachedFiles.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final f = entry.value;
                              final displayName = _customPickedNames[idx] ?? f.name;
                              final sizeKb = _getFileSizeBytes(f) / 1024;
                              final sizeStr = sizeKb > 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '${sizeKb.toStringAsFixed(1)} KB';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_getFileIcon(displayName), size: 18, color: const Color(0xFF2563EB)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$displayName ($sizeStr)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF64748B)),
                                      onPressed: () => _renamePickedFile(idx),
                                      splashRadius: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      tooltip: 'Rename File',
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFDC2626)),
                                      onPressed: () => _removeFile(idx),
                                      splashRadius: 14,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      tooltip: 'Remove',
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),

                    // 4. Adding Location Card
                    const Text(
                      'Location Card (Google Maps)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Paste a Google Maps link to automatically fetch coordinates, lat/long & location name',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 8),

                    TextField(
                      controller: _mapsUrlController,
                      onChanged: _onMapsUrlChanged,
                      decoration: InputDecoration(
                        hintText: 'https://www.google.com/maps/place/... or https://maps.app.goo.gl/...',
                        prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
                        suffixIcon: _isFetchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF2563EB)),
                                tooltip: 'Fetch Location Data',
                                onPressed: () => _fetchLocationData(_mapsUrlController.text),
                              ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),

                    if (_locationStatusMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _locationStatusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isFetchingLocation ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    // Fetched Location Card
                    if (_fetchedLocation != null) _buildLocationCard(_fetchedLocation!),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Modal Actions
            Row(
              children: [
                if (_errorMessage != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: _isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.itemToEdit != null ? 'Update Information' : 'Save Information', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Backwards compatibility alias
typedef AddDocumentDialog = AddInformationDialog;
