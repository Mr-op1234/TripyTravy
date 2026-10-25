import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../data/itinerary_database.dart';
import '../data/itinerary_file_manager.dart';
import 'widgets/smooth_scroll.dart';

class ItineraryExportEntry {
  final int number;
  final String title;
  final Directory folder;
  final List<File> files;

  const ItineraryExportEntry({
    required this.number,
    required this.title,
    required this.folder,
    required this.files,
  });
}

class ExportedItinerariesScreen extends StatefulWidget {
  final List<DestinationItem>? initialItineraries;

  const ExportedItinerariesScreen({
    super.key,
    this.initialItineraries,
  });

  @override
  State<ExportedItinerariesScreen> createState() => _ExportedItinerariesScreenState();
}

class _ExportedItinerariesScreenState extends State<ExportedItinerariesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ItineraryExportEntry> _entries = [];
  bool _isLoading = true;
  String? _rootFolderPath;
  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _filterQuery = _searchController.text.trim().toLowerCase();
      });
    });

    if (widget.initialItineraries != null) {
      int index = 1;
      final titles = <String>{...ItineraryFileManager.defaultItineraryNames};
      for (final item in widget.initialItineraries!) {
        titles.add(item.title);
      }
      _entries = titles.map((t) {
        return ItineraryExportEntry(
          number: index++,
          title: t,
          folder: Directory(t),
          files: const [],
        );
      }).toList();
      _isLoading = false;
    }

    _loadExportEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExportEntries() async {
    if (_entries.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final baseDir = await ItineraryFileManager.getBaseDirectory();
      _rootFolderPath = baseDir.path;

      // 1. Fetch itineraries from DB or provided props
      List<String> titles = [];
      if (widget.initialItineraries != null) {
        titles = widget.initialItineraries!.map((e) => e.title).toList();
      } else {
        final dbTrips = await ItineraryDatabase.instance.getAllItineraries();
        titles = dbTrips.map((e) => e.title).toList();
      }

      // 2. Ensure default pre-existing folders exist (Switzerland & Italy, Vietnam, Malaysia)
      await ItineraryFileManager.ensureDefaultFolders(titles);

      // 3. Collect unique itinerary names preserving default order
      final allNamesSet = <String>{};
      for (final def in ItineraryFileManager.defaultItineraryNames) {
        allNamesSet.add(def);
      }
      for (final t in titles) {
        if (t.trim().isNotEmpty) {
          allNamesSet.add(t.trim());
        }
      }

      // Also scan disk for any additional subfolders
      try {
        if (baseDir.existsSync()) {
          final entries = baseDir.listSync(recursive: false, followLinks: false);
          for (final entity in entries) {
            if (entity is Directory) {
              final folderName = p.basename(entity.path);
              if (!folderName.startsWith('.')) {
                allNamesSet.add(folderName);
              }
            }
          }
        }
      } catch (_) {}

      // 4. Build table entries
      final entries = <ItineraryExportEntry>[];
      int index = 1;
      for (final title in allNamesSet) {
        final folder = await ItineraryFileManager.ensureItineraryFolder(title);
        final files = await ItineraryFileManager.getExportedTtFiles(title);

        entries.add(
          ItineraryExportEntry(
            number: index++,
            title: title,
            folder: folder,
            files: files,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading exported entries: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterQuery.isEmpty
        ? _entries
        : _entries
            .where((e) =>
                e.title.toLowerCase().contains(_filterQuery) ||
                e.files.any((f) => p.basename(f.path).toLowerCase().contains(_filterQuery)))
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopAppBar(),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0066FF)),
                    )
                  : Scrollbar(
                      controller: _scrollController,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const ClampingScrollPhysics(),
                        child: SmoothScroll(
                          controller: _scrollController,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Info Banner with path and counts
                                _buildSummaryHeader(),

                                const SizedBox(height: 24),

                                // The Table Card
                                _buildTableCard(filtered),

                                const SizedBox(height: 48),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200, width: 1.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
              child: Row(
                children: [
                  // Back button to Dashboard
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF334155)),
                            SizedBox(width: 6),
                            Text(
                              'Back to Dashboard',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Title & Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0066FF), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Exported Itineraries',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Manage exported .tt containers and designated trip destination folders',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  const SizedBox(width: 32),

                  // Search Box
                  Container(
                    width: 240,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 17, color: Color(0xFF64748B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Search itinerary or .tt...',
                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Open Root Directory Button
                  OutlinedButton.icon(
                    onPressed: () => ItineraryFileManager.openBaseFolderInExplorer(),
                    icon: const Icon(Icons.folder_open_rounded, size: 15),
                    label: const Text('Open Root Folder', style: TextStyle(fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Refresh Button
                  IconButton(
                    tooltip: 'Refresh Listings',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                    onPressed: _loadExportEntries,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryHeader() {
    final totalTrips = _entries.length;
    final totalTtFiles = _entries.fold<int>(0, (sum, e) => sum + e.files.length);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Stat 1: Itinerary Folders
          _buildStatPill(
            icon: Icons.folder_rounded,
            iconColor: const Color(0xFF0284C7),
            label: 'Trip Folders',
            value: '$totalTrips',
          ),
          const SizedBox(width: 24),

          // Stat 2: Exported .tt Files
          _buildStatPill(
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFF0066FF),
            label: 'Exported .tt Files',
            value: '$totalTtFiles',
          ),

          const Spacer(),

          // Path pill
          if (_rootFolderPath != null)
            Flexible(
              child: Material(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => ItineraryFileManager.openBaseFolderInExplorer(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.folder_shared_outlined, size: 16, color: Color(0xFF0066FF)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Location: $_rootFolderPath',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF475569),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCard(List<ItineraryExportEntry> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Table Header Row: |No.|Itinerary Name|Exported itinerary|
            _buildTableHeader(),

            // Table Body Rows
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      Text(
                        _filterQuery.isEmpty
                            ? 'No itineraries found.'
                            : 'No itineraries matching "$_filterQuery"',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                itemBuilder: (context, index) {
                  final entry = items[index];
                  return _buildTableRow(entry, isEven: index % 2 == 0);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: const Row(
        children: [
          // Column 1: No.
          SizedBox(
            width: 70,
            child: Text(
              'No.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Column 2: Itinerary Name
          SizedBox(
            width: 280,
            child: Text(
              'Itinerary Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Column 3: Exported itinerary
          Expanded(
            child: Text(
              'Exported itinerary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Action column
          SizedBox(
            width: 120,
            child: Text(
              'Actions',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(ItineraryExportEntry entry, {required bool isEven}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: isEven ? Colors.white : const Color(0xFFFCFDFE),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1: No.
          SizedBox(
            width: 70,
            child: Text(
              '${entry.number}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),

          // Column 2: Itinerary Name
          SizedBox(
            width: 280,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: Color(0xFF0066FF),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Folder: ${p.basename(entry.folder.path)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Column 3: Exported itinerary (clickable listings taking user to folder)
          Expanded(
            child: entry.files.isEmpty
                ? _buildEmptyExportListing(entry)
                : _buildFilesExportListing(entry),
          ),

          // Column 4: Quick Action to open folder
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => ItineraryFileManager.openFolderInExplorer(entry.folder.path),
                icon: const Icon(Icons.folder_open_rounded, size: 14),
                label: const Text('Folder', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0066FF),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyExportListing(ItineraryExportEntry entry) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => ItineraryFileManager.openFolderInExplorer(entry.folder.path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder_outlined, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Folder: ${entry.title} (No .tt files exported yet)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '• Open folder',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF0066FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilesExportListing(ItineraryExportEntry entry) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entry.files.map((file) {
        final fileName = p.basename(file.path);
        int size = 0;
        try {
          size = file.lengthSync();
        } catch (_) {}

        return Tooltip(
          message: 'Click to open "${entry.title}" folder and select this file',
          child: Material(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => ItineraryFileManager.openFileInExplorer(file.path),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 15, color: Color(0xFF0066FF)),
                    const SizedBox(width: 6),
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Text(
                        _formatFileSize(size),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
