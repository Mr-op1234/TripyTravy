import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/itinerary_database.dart';

class ChangeBannerDialog extends StatefulWidget {
  final String currentBannerPath;
  final ValueChanged<String> onBannerSelected;

  const ChangeBannerDialog({
    super.key,
    required this.currentBannerPath,
    required this.onBannerSelected,
  });

  @override
  State<ChangeBannerDialog> createState() => _ChangeBannerDialogState();
}

class _ChangeBannerDialogState extends State<ChangeBannerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _urlController;
  String _selectedPath = '';
  String? _errorMessage;

  static const List<Map<String, String>> _presets = [
    {
      'name': 'Swiss Alps',
      'path': 'assets/images/switzerland_clean.png',
    },
    {
      'name': 'Mount Fuji & Kyoto',
      'path': 'assets/images/japan_clean.png',
    },
    {
      'name': 'Malaysia Rainforest',
      'path': 'assets/images/malaysia_clean.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedPath = widget.currentBannerPath;
    _urlController = TextEditingController(
      text: widget.currentBannerPath.startsWith('http') ? widget.currentBannerPath : '',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFromFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        dialogTitle: 'Select Banner Image',
      );
      if (files.isNotEmpty && files.first.path != null) {
        final saved = await ItineraryDatabase.saveBannerToAppStorage(files.first.path!);
        setState(() {
          _selectedPath = saved;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not pick file: $e';
      });
    }
  }

  Widget _buildPreview(String path) {
    if (path.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 40, color: Color(0xFF94A3B8)),
            SizedBox(height: 8),
            Text('No Banner Selected', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ],
        ),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('Failed to load image from URL', style: TextStyle(color: Color(0xFFDC2626))),
        ),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const Center(child: Text('Invalid image path'));
  }

  void _apply() {
    if (_tabController.index == 1) {
      final url = _urlController.text.trim();
      if (url.isNotEmpty) {
        _selectedPath = url;
      }
    }
    widget.onBannerSelected(_selectedPath);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Close
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF0066FF), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Change Trip Banner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Live Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: _buildPreview(_selectedPath),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
            ],
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0066FF),
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: const Color(0xFF0066FF),
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.upload_file_rounded, size: 18), text: 'Upload'),
                Tab(icon: Icon(Icons.link_rounded, size: 18), text: 'Paste URL'),
                Tab(icon: Icon(Icons.auto_awesome_rounded, size: 18), text: 'Presets'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            SizedBox(
              height: 130,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Upload
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromFile,
                      icon: const Icon(Icons.folder_open_rounded, color: Color(0xFF0066FF)),
                      label: const Text('Browse Local Images', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),

                  // Tab 2: URL
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'https://images.unsplash.com/...',
                          prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF0066FF)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (val) {
                          if (val.startsWith('http')) {
                            setState(() => _selectedPath = val.trim());
                          }
                        },
                      ),
                    ],
                  ),

                  // Tab 3: Presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _presets.map((preset) {
                      final isSelected = _selectedPath == preset['path'];
                      return InkWell(
                        onTap: () => setState(() => _selectedPath = preset['path']!),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 140,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0066FF) : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(preset['path']!, height: 60, width: double.infinity, fit: BoxFit.cover),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preset['name']!,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF0066FF) : const Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

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
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Apply Banner', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
