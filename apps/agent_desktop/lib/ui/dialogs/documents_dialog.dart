import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/itinerary_database.dart';

class DocumentsManagerDialog extends StatefulWidget {
  final int itineraryId;
  final String tripTitle;
  final List<TripEventItem> availableEvents;

  const DocumentsManagerDialog({
    super.key,
    required this.itineraryId,
    required this.tripTitle,
    this.availableEvents = const [],
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
    _loadDocuments();
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

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return const Color(0xFF0284C7);
      case 'hotel':
        return const Color(0xFF16A34A);
      case 'insurance':
        return const Color(0xFFDC2626);
      case 'visa':
        return const Color(0xFF9333EA);
      default:
        return const Color(0xFF2563EB);
    }
  }

  Color _getTypeBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return const Color(0xFFE0F2FE);
      case 'hotel':
        return const Color(0xFFDCFCE7);
      case 'insurance':
        return const Color(0xFFFEE2E2);
      case 'visa':
        return const Color(0xFFF3E8FF);
      default:
        return const Color(0xFFE8F0FE);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'flight':
        return Icons.flight_takeoff_rounded;
      case 'hotel':
        return Icons.hotel_rounded;
      case 'insurance':
        return Icons.health_and_safety_rounded;
      case 'visa':
        return Icons.badge_rounded;
      case 'passport':
        return Icons.contact_page_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  void _openFile(String path) {
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [path]);
      } else {
        Process.run('open', [path]);
      }
    } catch (_) {}
  }

  Future<void> _deleteDoc(TripDocumentItem doc) async {
    await ItineraryDatabase.instance.deleteDocument(doc.id);
    _loadDocuments();
  }

  void _showAddDocumentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddDocumentDialog(
        itineraryId: widget.itineraryId,
        availableEvents: widget.availableEvents,
        onDocumentSaved: () {
          _loadDocuments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.folder_shared_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trip Documents & Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Stored passes, vouchers, and bookings for ${widget.tripTitle}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Document list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _documents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.file_copy_outlined, size: 28, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No documents attached yet',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Attach flight tickets, hotel vouchers, visas, and insurance.',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _documents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            final color = _getTypeColor(doc.docType);
                            final bgColor = _getTypeBgColor(doc.docType);
                            final icon = _getTypeIcon(doc.docType);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              doc.title,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: bgColor,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                doc.docType.toUpperCase(),
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (doc.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            doc.description,
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 3),
                                        Text(
                                          '${doc.fileName} • ${doc.fileSize}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Open / View Document',
                                    onPressed: () => _openFile(doc.filePath),
                                    icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFF2563EB)),
                                    splashRadius: 18,
                                  ),
                                  IconButton(
                                    tooltip: 'Delete Document',
                                    onPressed: () => _deleteDoc(doc),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                    splashRadius: 18,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddDocumentDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('+ Add More Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

class AddDocumentDialog extends StatefulWidget {
  final int itineraryId;
  final List<TripEventItem> availableEvents;
  final VoidCallback onDocumentSaved;

  const AddDocumentDialog({
    super.key,
    required this.itineraryId,
    this.availableEvents = const [],
    required this.onDocumentSaved,
  });

  @override
  State<AddDocumentDialog> createState() => _AddDocumentDialogState();
}

class _AddDocumentDialogState extends State<AddDocumentDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _docType = 'flight';
  String? _selectedEventId;
  String? _pickedFilePath;
  String? _pickedFileName;
  String? _pickedFileSize;
  String? _errorMessage;

  static const _docTypes = [
    {'value': 'flight', 'label': 'Flight Ticket / Pass'},
    {'value': 'hotel', 'label': 'Hotel / Lodging Voucher'},
    {'value': 'visa', 'label': 'Visa / Travel Permit'},
    {'value': 'insurance', 'label': 'Travel Insurance'},
    {'value': 'passport', 'label': 'Passport Copy / ID'},
    {'value': 'other', 'label': 'Other Document'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Select Document',
      );
      if (files.isNotEmpty && files.first.path != null) {
        final f = files.first;
        final fileOnDisk = File(f.path!);
        final sizeBytes = await fileOnDisk.length();
        final sizeKb = sizeBytes / 1024;
        final sizeStr = sizeKb > 1024
            ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
            : '${sizeKb.toStringAsFixed(1)} KB';

        setState(() {
          _pickedFilePath = f.path;
          _pickedFileName = f.name;
          _pickedFileSize = sizeStr;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = f.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
          }
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not select file: $e');
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Title is required');
      return;
    }
    if (_pickedFilePath == null) {
      setState(() => _errorMessage = 'Please select a document file');
      return;
    }

    final savedPath = await ItineraryDatabase.saveDocumentToAppStorage(_pickedFilePath!);
    final docItem = TripDocumentItem(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      itineraryId: widget.itineraryId,
      eventId: _selectedEventId,
      docType: _docType,
      title: title,
      description: _descriptionController.text.trim(),
      fileName: _pickedFileName ?? 'document',
      fileSize: _pickedFileSize ?? 'Unknown',
      filePath: savedPath,
    );

    await ItineraryDatabase.instance.insertDocument(docItem);
    widget.onDocumentSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.note_add_rounded, color: Color(0xFF2563EB), size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Add New Document',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Document Type
            const Text('Document Type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _docType,
              items: _docTypes.map((t) {
                return DropdownMenuItem(value: t['value'], child: Text(t['label']!, style: const TextStyle(fontSize: 13.5)));
              }).toList(),
              onChanged: (val) => setState(() => _docType = val ?? 'other'),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // Title
            const Text('Document Title *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'e.g., Return Flight Tickets',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),

            // File Selector
            const Text('File Attachment *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF8FAFC),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.attach_file_rounded, color: Color(0xFF2563EB), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickedFileName != null ? '$_pickedFileName (${_pickedFileSize})' : 'Browse document file from PC...',
                        style: TextStyle(
                          fontSize: 13,
                          color: _pickedFileName != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          fontWeight: _pickedFileName != null ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
            ],
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Document', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
