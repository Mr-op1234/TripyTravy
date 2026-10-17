import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/itinerary_database.dart';

class TripEditorDialog extends StatefulWidget {
  final DestinationItem? itemToEdit;
  final ValueChanged<DestinationItem> onSave;

  const TripEditorDialog({
    super.key,
    this.itemToEdit,
    required this.onSave,
  });

  @override
  State<TripEditorDialog> createState() => _TripEditorDialogState();
}

class _TripEditorDialogState extends State<TripEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _bannerPath;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _errorMessage;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _titleController = TextEditingController(text: item?.title ?? '');
    _descriptionController = TextEditingController(text: item?.subtitle ?? '');
    _bannerPath = item?.imagePath ?? 'assets/images/switzerland_clean.png';

    if (item?.startDate != null) {
      _startDate = DateTime.tryParse(item!.startDate!) ?? DateTime.now();
    } else {
      _startDate = DateTime.now();
    }

    if (item?.endDate != null) {
      _endDate = DateTime.tryParse(item!.endDate!) ?? _startDate.add(const Duration(days: 6));
    } else {
      _endDate = _startDate.add(const Duration(days: 6));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) {
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year) {
      if (start.month == end.month) {
        return '${_months[start.month - 1]} ${start.day} - ${end.day}, ${start.year}';
      }
      return '${_months[start.month - 1]} ${start.day} - ${_months[end.month - 1]} ${end.day}, ${start.year}';
    }
    return '${_months[start.month - 1]} ${start.day}, ${start.year} - ${_months[end.month - 1]} ${end.day}, ${end.year}';
  }

  String _formatDuration(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    final count = days > 0 ? days : 1;
    return '$count Day${count > 1 ? 's' : ''}';
  }

  Future<void> _pickBanner() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        dialogTitle: 'Select Trip Banner Image',
      );

      if (files.isNotEmpty && files.first.path != null) {
        final sourcePath = files.first.path!;
        final savedPath = await ItineraryDatabase.saveBannerToAppStorage(sourcePath);
        setState(() {
          _bannerPath = savedPath;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not pick image: $e';
      });
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0066FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2040),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0066FF),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Trip Title is required.';
      });
      return;
    }

    final duration = _formatDuration(_startDate, _endDate);
    final dateRange = _formatDateRange(_startDate, _endDate);
    final banner = _bannerPath.isNotEmpty ? _bannerPath : 'assets/images/switzerland_clean.png';

    final updatedItem = DestinationItem(
      id: widget.itemToEdit?.id ?? 0,
      title: title,
      subtitle: description.isNotEmpty ? description : 'Custom travel itinerary.',
      duration: duration,
      dateRange: dateRange,
      imagePath: banner,
      startDate: _startDate.toIso8601String().split('T').first,
      endDate: _endDate.toIso8601String().split('T').first,
    );

    widget.onSave(updatedItem);
    Navigator.pop(context);
  }

  Widget _buildBannerPreview() {
    if (_bannerPath.startsWith('assets/')) {
      return Image.asset(
        _bannerPath,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 150,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    final file = File(_bannerPath);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 150,
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFF64748B)),
          SizedBox(height: 6),
          Text(
            'Upload trip banner from folder',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_location_alt_rounded,
                      color: const Color(0xFF0066FF),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Trip Itinerary' : 'Create New Trip',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. Trip Banner (With Upload from Folder button)
              const Text(
                'Trip Banner',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 125,
                      width: double.infinity,
                      child: _buildBannerPreview(),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: ElevatedButton.icon(
                        onPressed: _pickBanner,
                        icon: const Icon(Icons.folder_open_rounded, size: 15, color: Colors.white),
                        label: Text(
                          _bannerPath.startsWith('assets/') ? 'Upload from Folder' : 'Change Image',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.72),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Trip Title
              const Text(
                'Trip Title *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g., Swiss Alps Adventure',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  prefixIcon: const Icon(Icons.flight_takeoff_rounded, color: Color(0xFF0066FF), size: 20),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Trip Description
              const Text(
                'Trip Description',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'e.g., Breathtaking mountain peaks, charming alpine towns, and crystal lakes.',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Icon(Icons.description_outlined, color: Color(0xFF0066FF), size: 20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0066FF), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. Start Date and End Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Date *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _selectStartDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0066FF)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _formatDate(_startDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
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
                        const Text(
                          'End Date *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _selectEndDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFF8FAFC),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available_rounded, size: 16, color: Color(0xFF0066FF)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _formatDate(_endDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Duration Preview Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timelapse_rounded, size: 14, color: Color(0xFF0066FF)),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDuration(_startDate, _endDate)} (${_formatDateRange(_startDate, _endDate)})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0066FF),
                      ),
                    ),
                  ],
                ),
              ),

              // Error Message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0066FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      isEditing ? 'Save Changes' : 'Create Itinerary',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
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
