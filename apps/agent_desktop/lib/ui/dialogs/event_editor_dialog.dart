import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/itinerary_database.dart';
import '../widgets/rich_description_editor.dart';

class EventEditorDialog extends StatefulWidget {
  final int itineraryId;
  final TripEventItem? eventToEdit;
  final ValueChanged<TripEventItem> onSave;

  const EventEditorDialog({
    super.key,
    required this.itineraryId,
    this.eventToEdit,
    required this.onSave,
  });

  @override
  State<EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<EventEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _coverImage = '';
  List<String> _photos = [];
  int _dayNumber = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final ev = widget.eventToEdit;
    _titleController = TextEditingController(text: ev?.title ?? '');
    _locationController = TextEditingController(text: ev?.location ?? '');
    _descriptionController = TextEditingController(text: ev?.description ?? '');
    _notesController = TextEditingController(text: (ev?.notes ?? []).join('\n'));
    _coverImage = ev?.coverImage ?? '';
    _photos = List.from(ev?.photos ?? []);
    _dayNumber = ev?.dayNumber ?? 1;

    if (ev != null && ev.eventDate.isNotEmpty) {
      _selectedDate = DateTime.tryParse(ev.eventDate) ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    if (ev?.startTime != null && ev!.startTime!.contains(':')) {
      final parts = ev.startTime!.split(':');
      _startTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts[1]) ?? 0);
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 0);
    }

    if (ev?.endTime != null && ev!.endTime!.contains(':')) {
      final parts = ev.endTime!.split(':');
      _endTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 11, minute: int.tryParse(parts[1]) ?? 30);
    } else {
      _endTime = const TimeOfDay(hour: 11, minute: 30);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hour.toString().padLeft(2, '0');
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _calculateDuration() {
    if (_startTime == null || _endTime == null) return '~ 1 hr';
    final startMin = _startTime!.hour * 60 + _startTime!.minute;
    final endMin = _endTime!.hour * 60 + _endTime!.minute;
    int diff = endMin - startMin;
    if (diff < 0) diff += 24 * 60; // crosses midnight

    final hours = diff ~/ 60;
    final minutes = diff % 60;

    if (hours > 0 && minutes > 0) {
      return '~ $hours hr${hours > 1 ? 's' : ''} $minutes mins';
    } else if (hours > 0) {
      return '~ $hours hr${hours > 1 ? 's' : ''}';
    } else {
      return '~ $minutes mins';
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final saved = await ItineraryDatabase.saveEventPhotoToAppStorage(files.first.path!);
        setState(() => _coverImage = saved);
      }
    } catch (_) {}
  }

  Future<void> _pickGalleryPhotos() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );
      if (files.isNotEmpty) {
        for (final f in files) {
          if (f.path != null) {
            final saved = await ItineraryDatabase.saveEventPhotoToAppStorage(f.path!);
            setState(() {
              if (!_photos.contains(saved)) _photos.add(saved);
            });
          }
        }
      }
    } catch (_) {}
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Event Title is required.');
      return;
    }

    final notes = _notesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final item = TripEventItem(
      id: widget.eventToEdit?.id ?? 'evt_${DateTime.now().millisecondsSinceEpoch}',
      itineraryId: widget.itineraryId,
      dayNumber: _dayNumber,
      title: title,
      eventDate: _selectedDate.toIso8601String().split('T').first,
      startTime: _startTime != null ? _formatTime(_startTime!) : null,
      endTime: _endTime != null ? _formatTime(_endTime!) : null,
      duration: _calculateDuration(),
      location: _locationController.text.trim(),
      description: _descriptionController.text.trim(),
      coverImage: _coverImage,
      photos: _photos,
      notes: notes,
      sortOrder: widget.eventToEdit?.sortOrder ?? 0,
    );

    widget.onSave(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;
    final dateStr = '${_selectedDate.day.toString().padLeft(2, '0')}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(26),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_calendar_rounded : Icons.add_circle_outline_rounded,
                      color: const Color(0xFF0066FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Itinerary Event' : 'Add Itinerary Event',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Title
              const Text('Event Title *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g., Departure from CCU or Mount Pilatus Summit',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Date & Times Row
              Row(
                children: [
                  // Date
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0066FF)),
                                const SizedBox(width: 8),
                                Text(dateStr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Start Time
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickStartTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _startTime != null ? _formatTime(_startTime!) : '--:--',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // End Time
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _pickEndTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _endTime != null ? _formatTime(_endTime!) : '--:--',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Duration Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFF0066FF)),
                    const SizedBox(width: 6),
                    Text(
                      'Calculated Duration: ${_calculateDuration()}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0066FF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Location / Google Maps Pin
              const Text('Location / Venue', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g., CCU - Kolkata Airport, or Lucerne Lake Pier',
                  prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF0066FF), size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Cover Image
              const Text('Event Cover Image', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_coverImage.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          _coverImage.startsWith('assets/')
                              ? Image.asset(_coverImage, width: 80, height: 50, fit: BoxFit.cover)
                              : Image.file(File(_coverImage), width: 80, height: 50, fit: BoxFit.cover),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: InkWell(
                              onTap: () => setState(() => _coverImage = ''),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _pickCoverImage,
                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                    label: Text(_coverImage.isEmpty ? 'Select Cover Photo' : 'Change Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description
              const Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              RichDescriptionEditor(
                controller: _descriptionController,
                placeholder: 'Detailed itinerary notes, schedule milestones, and check-in instructions...',
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 14),

              // Additional Notes
              const Text('Additional Notes (1 per line)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              const SizedBox(height: 6),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g.,\nWear comfortable shoes\nArrive 30 minutes early',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),

              // Gallery Photos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gallery Photos (${_photos.length})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                  TextButton.icon(
                    onPressed: _pickGalleryPhotos,
                    icon: const Icon(Icons.photo_library_outlined, size: 15),
                    label: const Text('Add Photos', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 65,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final p = _photos[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            Image.file(File(p), width: 90, height: 65, fit: BoxFit.cover),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: () => setState(() => _photos.removeAt(index)),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
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
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isEditing ? 'Save Changes' : 'Add Event', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
