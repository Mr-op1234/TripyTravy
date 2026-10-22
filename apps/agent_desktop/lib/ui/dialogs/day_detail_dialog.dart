import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/itinerary_database.dart';
import '../../data/google_maps_helper.dart';
import '../widgets/rich_description_editor.dart';

/// Small popup dialog to add or edit a Day Name.
class AddDayDialog extends StatefulWidget {
  final int itineraryId;
  final TripDayItem? dayToEdit;
  final int nextDayNumber;
  final VoidCallback onDaySaved;

  const AddDayDialog({
    super.key,
    required this.itineraryId,
    this.dayToEdit,
    required this.nextDayNumber,
    required this.onDaySaved,
  });

  @override
  State<AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<AddDayDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _dateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.dayToEdit?.title ?? 'Day ${widget.nextDayNumber}',
    );
    _dateController = TextEditingController(
      text: widget.dayToEdit?.date ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _saveDay() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      if (widget.dayToEdit != null) {
        final updated = widget.dayToEdit!.copyWith(
          title: title,
          date: _dateController.text.trim().isEmpty
              ? null
              : _dateController.text.trim(),
        );
        await ItineraryDatabase.instance.updateDay(updated);
      } else {
        final newDay = TripDayItem(
          id: 'day_${widget.itineraryId}_${DateTime.now().millisecondsSinceEpoch}',
          itineraryId: widget.itineraryId,
          dayNumber: widget.nextDayNumber,
          title: title,
          date: _dateController.text.trim().isEmpty
              ? null
              : _dateController.text.trim(),
          sortOrder: widget.nextDayNumber - 1,
        );
        await ItineraryDatabase.instance.insertDay(newDay);
      }

      if (mounted) {
        Navigator.pop(context, true);
        widget.onDaySaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save day: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.dayToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF2563EB), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? 'Edit Day' : 'Add Day',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Day Name input
            const Text(
              'Day Name *',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g. Day 1 - Arrival in Zurich',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
              onSubmitted: (_) => _saveDay(),
            ),
            const SizedBox(height: 16),

            // Optional Date
            const Text(
              'Date (Optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                hintText: 'e.g. 24-10-2026',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
              ),
              onSubmitted: (_) => _saveDay(),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveDay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Save Changes' : 'Create Day',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen-style Day Details modal displaying events in the exact Information Documents structure.
class DayDetailDialog extends StatefulWidget {
  final TripDayItem day;
  final String tripTitle;
  final VoidCallback onDayChanged;
  final List<TripEventItem>? initialEvents;

  const DayDetailDialog({
    super.key,
    required this.day,
    required this.tripTitle,
    required this.onDayChanged,
    this.initialEvents,
  });

  @override
  State<DayDetailDialog> createState() => _DayDetailDialogState();
}

class _DayDetailDialogState extends State<DayDetailDialog> {
  late TripDayItem _currentDay;
  List<TripEventItem> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentDay = widget.day;
    if (widget.initialEvents != null) {
      _events = List.from(widget.initialEvents!);
      _isLoading = false;
    } else {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final events = await ItineraryDatabase.instance.getEventsForDay(
      _currentDay.itineraryId,
      _currentDay.id,
    );
    if (mounted) {
      setState(() {
        _events = events;
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
        } else if (Platform.isMacOS) {
          Process.run('open', [path]);
        } else {
          Process.run('xdg-open', [path]);
        }
        return;
      }
      final file = File(path);
      if (file.existsSync()) {
        if (Platform.isWindows) {
          Process.run('explorer.exe', [path]);
        } else if (Platform.isMacOS) {
          Process.run('open', [path]);
        } else {
          Process.run('xdg-open', [path]);
        }
      }
    } catch (_) {}
  }

  void _showAddEventDialog({TripEventItem? eventToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => AddEventDialog(
        itineraryId: _currentDay.itineraryId,
        dayId: _currentDay.id,
        dayNumber: _currentDay.dayNumber,
        eventToEdit: eventToEdit,
        onEventSaved: () {
          _loadEvents();
          widget.onDayChanged();
        },
      ),
    );
  }

  void _showEditDayNameDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AddDayDialog(
        itineraryId: _currentDay.itineraryId,
        dayToEdit: _currentDay,
        nextDayNumber: _currentDay.dayNumber,
        onDaySaved: () async {
          final days = await ItineraryDatabase.instance
              .getDaysForItinerary(_currentDay.itineraryId);
          final updated = days.firstWhere((d) => d.id == _currentDay.id,
              orElse: () => _currentDay);
          if (mounted) {
            setState(() => _currentDay = updated);
            widget.onDayChanged();
          }
        },
      ),
    );
  }

  Future<void> _deleteEvent(TripEventItem event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ItineraryDatabase.instance.deleteEvent(event.id);
      _loadEvents();
      widget.onDayChanged();
    }
  }

  String _getFriendlyFileType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'PDF Document';
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return 'Image Document';
    }
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
      return 'Word Document';
    }
    if (lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.csv')) {
      return 'Spreadsheet';
    }
    if (lower.endsWith('.txt')) {
      return 'Text Document';
    }
    return 'Document';
  }

  Widget _buildAttachmentPill(Map<String, String> att) {
    final name = att['name'] ?? 'Document';
    final size = att['size'] ?? '';
    final path = att['path'] ?? '';
    final typeStr = _getFriendlyFileType(name);
    final subtitle = size.isNotEmpty ? '$typeStr · $size' : typeStr;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(13)),
            ),
            child: const Center(
              child: Icon(Icons.attach_file_rounded,
                  size: 22, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Preview / Open Document',
            onPressed: () => _openFile(path),
            icon: const Icon(Icons.visibility_outlined,
                size: 19, color: Color(0xFF0F172A)),
            splashRadius: 18,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photoPath) {
    final isAsset = photoPath.startsWith('assets/');
    final file = File(photoPath);

    return InkWell(
      onTap: () => _openFile(photoPath),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
          color: const Color(0xFFF1F5F9),
        ),
        clipBehavior: Clip.antiAlias,
        child: isAsset
            ? Image.asset(photoPath, fit: BoxFit.cover)
            : (file.existsSync()
                ? Image.file(file, fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: Color(0xFF94A3B8)))),
      ),
    );
  }

  Widget _buildEventCard(TripEventItem event) {
    final hasAttachments = event.attachments.isNotEmpty;
    final hasPhotos = event.photos.isNotEmpty;

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
          // Header Row: 6-dot drag indicator, Blue Event Badge, Title, Edit button, 3-dots menu
          Row(
            children: [
              const Icon(Icons.drag_indicator_rounded,
                  color: Color(0xFFCBD5E1), size: 20),
              const SizedBox(width: 10),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.event_note_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  event.title.toUpperCase(),
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
                tooltip: 'Edit Event',
                onPressed: () => _showAddEventDialog(eventToEdit: event),
                icon: const Icon(Icons.edit_outlined,
                    size: 19, color: Color(0xFF64748B)),
                splashRadius: 18,
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 20, color: Color(0xFF64748B)),
                splashRadius: 18,
                onSelected: (val) {
                  if (val == 'edit') _showAddEventDialog(eventToEdit: event);
                  if (val == 'delete') _deleteEvent(event);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Edit Event', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Delete Event',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Description & Clickable Links
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            RichDescriptionView(
              description: event.description,
              mapUrl: event.mapUrl,
              onOpenUrl: _openFile,
              style: const TextStyle(
                  fontSize: 14.5, color: Color(0xFF334155), height: 1.55),
            ),
          ],

          // Location Card (if present)
          if (event.hasLocation ||
              (event.mapUrl != null && event.mapUrl!.isNotEmpty)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.locationName ??
                              (event.location.isNotEmpty
                                  ? event.location
                                  : 'Location'),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event.hasCoordinates) ...[
                          const SizedBox(height: 2),
                          Text(
                            event.coordinatesDisplay,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (event.mapUrl != null && event.mapUrl!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _openFile(event.mapUrl!),
                      icon: const Icon(Icons.open_in_new_rounded,
                          size: 14, color: Color(0xFF2563EB)),
                      label: const Text('Open Map',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],

          // Actual Photos / Images Gallery (Distinct from documents!)
          if (hasPhotos) ...[
            const SizedBox(height: 16),
            const Text(
              'PHOTOS',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  event.photos.map((p) => _buildPhotoThumbnail(p)).toList(),
            ),
          ],

          // Attachment Pills (Documents: PDF, vouchers, passes)
          if (hasAttachments) ...[
            const SizedBox(height: 16),
            const Text(
              'DOCUMENTS & PASSES',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Column(
              children: event.attachments.map((att) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildAttachmentPill(att),
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
                  child: const Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _currentDay.title,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Edit Day Name',
                            icon: const Icon(Icons.edit_outlined,
                                size: 18, color: Color(0xFF64748B)),
                            onPressed: _showEditDayNameDialog,
                            splashRadius: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentDay.date != null && _currentDay.date!.isNotEmpty
                            ? '${_currentDay.date} · ${_events.length} events planned for ${widget.tripTitle}'
                            : '${_events.length} events planned for ${widget.tripTitle}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: Color(0xFF64748B), size: 22),
                  tooltip: 'Close (Esc)',
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Events List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _events.isEmpty
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
                                child: const Icon(Icons.event_note_outlined,
                                    size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'No events added to this day yet',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155)),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Plan flights, activities, sightseeing tours, and dining below.',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          itemCount: _events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            return _buildEventCard(_events[index]);
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Close',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEventDialog(),
                  icon: const Icon(Icons.add_rounded, size: 19),
                  label: const Text('Add Event',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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

/// Dialog to Add / Edit an Event with Title, Rich Description, Location Card, Documents, and Images.
class AddEventDialog extends StatefulWidget {
  final int itineraryId;
  final String dayId;
  final int dayNumber;
  final TripEventItem? eventToEdit;
  final VoidCallback onEventSaved;

  // Supported image file formats
  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
  ];

  const AddEventDialog({
    super.key,
    required this.itineraryId,
    required this.dayId,
    required this.dayNumber,
    this.eventToEdit,
    required this.onEventSaved,
  });

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _mapsUrlController = TextEditingController();

  final List<PlatformFile> _attachedFiles = [];
  List<Map<String, String>> _existingAttachments = [];
  final List<String> _photosList = [];

  GoogleMapsLocation? _fetchedLocation;
  bool _isFetchingLocation = false;
  String? _locationStatusMessage;
  String? _errorMessage;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      final e = widget.eventToEdit!;
      _titleController.text = e.title;
      _descriptionController.text = e.description;
      _mapsUrlController.text = e.mapUrl ?? '';
      _photosList.addAll(e.photos);

      if (e.hasLocation || e.hasCoordinates) {
        _fetchedLocation = GoogleMapsLocation(
          locationName: e.locationName ?? e.location,
          latitude: e.latitude,
          longitude: e.longitude,
          rawUrl: e.mapUrl ?? '',
        );
      }

      _existingAttachments = List<Map<String, String>>.from(e.attachments);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _mapsUrlController.dispose();
    super.dispose();
  }

  int _getFileSizeBytes(PlatformFile f) {
    if (f.path != null && File(f.path!).existsSync()) {
      try {
        return File(f.path!).lengthSync();
      } catch (_) {}
    }
    return 0;
  }

  // Supported image file formats
  static const List<String> supportedImageExtensions = [
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
    'bmp',
    'heic',
  ];

  // Pick Document Files (PDF, Word, TXT, etc.)
  Future<void> _pickDocuments() async {
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

  // Pick Image Files ONLY (PNG, JPG, WEBP, GIF - distinct from documents!)
  Future<void> _pickPhotos() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedImageExtensions,
        dialogTitle: 'Select Images to Add (PNG, JPG, WEBP, GIF)',
      );
      if (files.isNotEmpty) {
        setState(() {
          for (final f in files) {
            final p = f.path;
            if (p != null && p.isNotEmpty) {
              final ext = p.split('.').last.toLowerCase();
              if (supportedImageExtensions.contains(ext) &&
                  !_photosList.contains(p)) {
                _photosList.add(p);
              }
            }
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not select images: $e');
    }
  }

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
            _locationStatusMessage =
                'Could not extract location data from link. Please check the URL.';
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

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Event Title is required.');
      return;
    }

    final combinedAttachments = <Map<String, String>>[..._existingAttachments];
    for (final f in _attachedFiles) {
      if (f.path != null) {
        final sizeBytes = _getFileSizeBytes(f);
        final sizeMb = (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
        final sizeStr = sizeBytes > 1024 * 1024
            ? '$sizeMb MB'
            : '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
        combinedAttachments.add({
          'name': f.name,
          'size': sizeStr,
          'path': f.path!,
        });
      }
    }

    final attachmentsJson =
        combinedAttachments.isNotEmpty ? jsonEncode(combinedAttachments) : null;

    final event = TripEventItem(
      id: widget.eventToEdit?.id ??
          'evt_${widget.itineraryId}_${DateTime.now().millisecondsSinceEpoch}',
      itineraryId: widget.itineraryId,
      dayId: widget.dayId,
      dayNumber: widget.dayNumber,
      title: title,
      eventDate: widget.eventToEdit?.eventDate ?? '',
      startTime: widget.eventToEdit?.startTime,
      endTime: widget.eventToEdit?.endTime,
      duration: widget.eventToEdit?.duration ?? '',
      location:
          _fetchedLocation?.locationName ?? widget.eventToEdit?.location ?? '',
      description: _descriptionController.text.trim(),
      coverImage: _photosList.isNotEmpty
          ? _photosList.first
          : (widget.eventToEdit?.coverImage ?? ''),
      photos: _photosList,
      notes: widget.eventToEdit?.notes ?? [],
      sortOrder: widget.eventToEdit?.sortOrder ?? 0,
      locationName: _fetchedLocation?.locationName,
      latitude: _fetchedLocation?.latitude,
      longitude: _fetchedLocation?.longitude,
      mapUrl: _mapsUrlController.text.trim().isEmpty
          ? null
          : _mapsUrlController.text.trim(),
      attachmentsJson: attachmentsJson,
    );

    try {
      if (widget.eventToEdit != null) {
        await ItineraryDatabase.instance.updateEvent(event);
      } else {
        await ItineraryDatabase.instance.insertEvent(event);
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onEventSaved();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to save event: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.eventToEdit != null;
    final totalAttachmentsCount =
        _existingAttachments.length + _attachedFiles.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 820,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.90),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.event_available_rounded,
                        color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Event' : 'Add Event',
                          style: const TextStyle(
                              fontSize: 18.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Add title, rich description, location card, photos, and attached documents.',
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        color: Color(0xFF64748B), size: 20),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(_errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFDC2626),
                                        fontSize: 13))),
                          ],
                        ),
                      ),

                    // 1. Event Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Text(
                            'Event Title *',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B)),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. Flight to Zurich, Lake Boat Tour, or Dinner at Lindenhof',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2563EB), width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(
                          color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 2. Event Description (RichDescriptionEditor)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: 140,
                            child: Text(
                              'Description',
                              style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: RichDescriptionEditor(
                            controller: _descriptionController,
                            placeholder:
                                'Write event details with bold, italics, highlights, and tables...',
                            minLines: 4,
                            maxLines: 8,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(
                          color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 3. Location Card Section (Google Maps auto-fetch)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Location Card',
                                    style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B))),
                                SizedBox(height: 2),
                                Text('Google Maps Link',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _mapsUrlController,
                                onChanged: _onMapsUrlChanged,
                                decoration: InputDecoration(
                                  hintText:
                                      'Paste Google Maps place or coordinates link (https://maps.google.com/...)',
                                  prefixIcon: const Icon(
                                      Icons.location_on_outlined,
                                      color: Color(0xFF2563EB),
                                      size: 20),
                                  suffixIcon: _isFetchingLocation
                                      ? const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)))
                                      : null,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFFCBD5E1))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF2563EB),
                                          width: 1.5)),
                                ),
                              ),
                              if (_locationStatusMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(_locationStatusMessage!,
                                    style: const TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                        fontStyle: FontStyle.italic)),
                              ],
                              if (_fetchedLocation != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: const Color(0xFFBFDBFE)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFF2563EB),
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.place_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _fetchedLocation!.locationName,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1E3A8A)),
                                            ),
                                            if (_fetchedLocation!
                                                .hasCoordinates) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Lat: ${_fetchedLocation!.latitude!.toStringAsFixed(4)}°, Lng: ${_fetchedLocation!.longitude!.toStringAsFixed(4)}°',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF3B82F6)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Chip(
                                        label: Text('Auto-Fetched',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D4ED8))),
                                        backgroundColor: Color(0xFFDBEAFE),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(
                          color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 4. Photos & Images Section (Actual PNG / JPG files!)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Photos & Images',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B))),
                              SizedBox(height: 2),
                              Text('PNG, JPG, WEBP, GIF',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickPhotos,
                                icon: const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    size: 18),
                                label: const Text(
                                    'Add Images (PNG, JPG, WEBP, GIF)'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                              ),
                              if (_photosList.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children:
                                      _photosList.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final path = entry.value;
                                    final file = File(path);
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: const Color(0xFFCBD5E1)),
                                            color: const Color(0xFFF1F5F9),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: path.startsWith('assets/')
                                              ? Image.asset(path,
                                                  fit: BoxFit.cover)
                                              : (file.existsSync()
                                                  ? Image.file(file,
                                                      fit: BoxFit.cover)
                                                  : const Icon(Icons.image,
                                                      color:
                                                          Color(0xFF94A3B8))),
                                        ),
                                        Positioned(
                                          top: 2,
                                          right: 2,
                                          child: InkWell(
                                            onTap: () => setState(() =>
                                                _photosList.removeAt(idx)),
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                  color: Colors.black54,
                                                  shape: BoxShape.circle),
                                              child: const Icon(Icons.close,
                                                  color: Colors.white,
                                                  size: 14),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Divider(
                          color: Color(0xFFF1F5F9), height: 1, thickness: 1.2),
                    ),

                    // 5. Attach Documents Section (PDF, vouchers, passes)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Documents',
                                  style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B))),
                              SizedBox(height: 2),
                              Text('Passes & Vouchers',
                                  style: TextStyle(
                                      fontSize: 12, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickDocuments,
                                icon: const Icon(Icons.attach_file_rounded,
                                    size: 18),
                                label: const Text(
                                    'Attach Documents (PDF, Vouchers)'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2563EB),
                                  side: const BorderSide(
                                      color: Color(0xFF2563EB)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                              ),
                              if (totalAttachmentsCount > 0) ...[
                                const SizedBox(height: 12),
                                Column(
                                  children: [
                                    ..._existingAttachments
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final idx = entry.key;
                                      final att = entry.value;
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: _buildAttachmentRow(
                                            att['name'] ?? 'File',
                                            att['size'] ?? '', () {
                                          setState(() => _existingAttachments
                                              .removeAt(idx));
                                        }),
                                      );
                                    }),
                                    ..._attachedFiles
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final idx = entry.key;
                                      final f = entry.value;
                                      final sizeBytes = _getFileSizeBytes(f);
                                      final sizeStr = sizeBytes > 1024 * 1024
                                          ? '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
                                          : '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: _buildAttachmentRow(
                                            f.name, sizeStr, () {
                                          setState(() =>
                                              _attachedFiles.removeAt(idx));
                                        }),
                                      );
                                    }),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                    ),
                    child: Text(isEditing ? 'Save Event' : 'Create Event',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(String name, String size, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 18, color: Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$name ${size.isNotEmpty ? "($size)" : ""}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
            onPressed: onRemove,
            splashRadius: 14,
          ),
        ],
      ),
    );
  }
}
