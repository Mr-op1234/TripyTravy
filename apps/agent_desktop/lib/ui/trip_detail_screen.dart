import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../data/itinerary_database.dart';
import '../data/itinerary_file_manager.dart';
import '../data/itinerary_tt_compiler.dart';

import 'dialogs/change_banner_dialog.dart';

import 'dialogs/documents_dialog.dart';

import 'dialogs/day_detail_dialog.dart';

import 'widgets/smooth_scroll.dart';

import 'widgets/rich_description_editor.dart';

class TripDetailScreen extends StatefulWidget {
  @visibleForTesting
  static Future<Uri?> Function({
    required String fileName,
    required Uint8List bytes,
    String? dialogTitle,
    String? initialDirectory,
    FileType? type,
    List<String>? allowedExtensions,
  })? saveFilePickerOverride;

  final DestinationItem item;

  final List<TripDayItem>? initialDays;

  final List<TripEventItem>? initialEvents;

  final List<TripDocumentItem>? initialDocuments;

  const TripDetailScreen({
    super.key,
    required this.item,
    this.initialDays,
    this.initialEvents,
    this.initialDocuments,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late DestinationItem _currentTrip;

  late final ScrollController _scrollController;

  List<TripDayItem> _days = [];

  Map<String, int> _dayEventCounts = {};

  List<TripEventItem> _events = [];

  List<TripDocumentItem> _documents = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _currentTrip = widget.item;

    if (widget.initialEvents != null || widget.initialDays != null) {
      if (widget.initialDays != null) {
        _days = List.from(widget.initialDays!);
      }

      _events = List.from(widget.initialEvents ?? []);

      _documents = List.from(widget.initialDocuments ?? []);

      // If days are empty but initialEvents exist, synthesize day cards

      if (_days.isEmpty) {
        if (_events.isNotEmpty) {
          final dayNumbers = _events.map((e) => e.dayNumber).toSet().toList()
            ..sort();

          for (final dn in dayNumbers) {
            _days.add(TripDayItem(
              id: 'day_${widget.item.id}_$dn',
              itineraryId: widget.item.id,
              dayNumber: dn,
              title: 'Day $dn',
              sortOrder: dn - 1,
            ));
          }
        } else if (widget.initialDays == null) {
          final dayCount = ItineraryDatabase.parseDurationDays(
            widget.item.duration,
            startDate: widget.item.startDate,
            endDate: widget.item.endDate,
          );
          DateTime? startDate =
              ItineraryDatabase.parseFlexibleDate(widget.item.startDate);
          if (startDate == null && widget.item.dateRange.isNotEmpty) {
            final rangeMatch =
                RegExp(r'(\d{2}-\d{2}-\d{4})\s*->\s*(\d{2}-\d{2}-\d{4})')
                    .firstMatch(widget.item.dateRange);
            if (rangeMatch != null) {
              startDate =
                  ItineraryDatabase.parseFlexibleDate(rangeMatch.group(1));
            }
          }
          for (int i = 1; i <= dayCount; i++) {
            String? dateStr;
            if (startDate != null) {
              final d = startDate.add(Duration(days: i - 1));
              dateStr =
                  '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
            }
            _days.add(TripDayItem(
              id: 'day_${widget.item.id}_$i',
              itineraryId: widget.item.id,
              dayNumber: i,
              title: 'Day $i',
              date: dateStr,
              sortOrder: i - 1,
            ));
          }
        }
      }

      final counts = <String, int>{};

      for (final e in _events) {
        if (e.dayId != null) {
          counts[e.dayId!] = (counts[e.dayId!] ?? 0) + 1;
        } else {
          counts['day_${e.dayNumber}'] =
              (counts['day_${e.dayNumber}'] ?? 0) + 1;
        }
      }

      _dayEventCounts = counts;

      _isLoading = false;
    } else {
      _loadTripData();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _loadTripData() async {
    final updatedTrip =
        await ItineraryDatabase.instance.getItineraryById(_currentTrip.id);
    if (updatedTrip != null) _currentTrip = updatedTrip;

    var days =
        await ItineraryDatabase.instance.getDaysForItinerary(_currentTrip.id);

    // Auto-create days if itinerary has none yet
    if (days.isEmpty) {
      await ItineraryDatabase.instance.autoCreateDaysForItinerary(_currentTrip);
      days =
          await ItineraryDatabase.instance.getDaysForItinerary(_currentTrip.id);
    }

    final events =
        await ItineraryDatabase.instance.getEventsForItinerary(_currentTrip.id);

    final docs = await ItineraryDatabase.instance
        .getDocumentsForItinerary(_currentTrip.id);

    final counts = <String, int>{};

    for (final e in events) {
      if (e.dayId != null) {
        counts[e.dayId!] = (counts[e.dayId!] ?? 0) + 1;
      } else {
        counts['day_${e.dayNumber}'] = (counts['day_${e.dayNumber}'] ?? 0) + 1;
      }
    }

    if (mounted) {
      setState(() {
        _days = days;

        _dayEventCounts = counts;

        _events = events;

        _documents = docs;

        _isLoading = false;
      });
    }
  }

  void _showAddDayDialog({TripDayItem? dayToEdit}) {
    String? defaultDate;
    if (dayToEdit == null) {
      DateTime? startDate =
          ItineraryDatabase.parseFlexibleDate(_currentTrip.startDate);
      if (startDate != null) {
        final nextD = startDate.add(Duration(days: _days.length));
        defaultDate =
            '${nextD.day.toString().padLeft(2, '0')}-${nextD.month.toString().padLeft(2, '0')}-${nextD.year}';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AddDayDialog(
        itineraryId: _currentTrip.id,
        dayToEdit: dayToEdit,
        nextDayNumber: _days.length + 1,
        defaultDate: defaultDate,
        onDaySaved: () {
          _loadTripData();
        },
      ),
    );
  }

  void _openDayDetails(TripDayItem day) {
    showDialog(
      context: context,
      builder: (ctx) => DayDetailDialog(
        day: day,
        tripTitle: _currentTrip.title,
        onDayChanged: () {
          _loadTripData();
        },
      ),
    );
  }

  Future<void> _deleteDay(TripDayItem day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Day'),
        content: Text(
            'Are you sure you want to delete "${day.title}" and all its events?'),
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
      await ItineraryDatabase.instance.deleteDay(day.id);

      _loadTripData();
    }
  }

  void _showChangeBannerDialog() {
    showDialog(
      context: context,
      builder: (_) => ChangeBannerDialog(
        currentBannerPath: _currentTrip.imagePath,
        onBannerSelected: (newPath) async {
          final updated = _currentTrip.copyWith(imagePath: newPath);

          await ItineraryDatabase.instance.updateItinerary(updated);

          setState(() {
            _currentTrip = updated;
          });
        },
      ),
    );
  }

  void _showDocumentsDialog() {
    showDialog(
      context: context,
      builder: (_) => DocumentsManagerDialog(
        itineraryId: _currentTrip.id,
        tripTitle: _currentTrip.title,
        availableEvents: _events,
        initialDocuments: widget.initialDocuments != null ? _documents : null,
      ),
    ).then((_) => _loadTripData());
  }

  Future<void> _exportToTtFile() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Text('Compiling "${_currentTrip.title}" into encrypted .tt file...'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );

    try {
      final bytes = await ItineraryTtCompiler.compile(
        trip: _currentTrip,
        days: _days,
        events: _events,
        documents: _documents,
      );

      final defaultFileName = ItineraryFileManager.generateTtFileName(_currentTrip.title);
      final itineraryFolder = await ItineraryFileManager.ensureItineraryFolder(_currentTrip.title);

      // Save directly into the designated itinerary folder
      final savedFile = await ItineraryFileManager.saveTtFile(
        itineraryTitle: _currentTrip.title,
        bytes: bytes,
        customFileName: defaultFileName,
      );

      // Internally open file explorer save dialog so user can save in their directory
      String? userSavedPath;
      try {
        final uri = TripDetailScreen.saveFilePickerOverride != null
            ? await TripDetailScreen.saveFilePickerOverride!(
                dialogTitle: 'Save Itinerary .tt Container',
                fileName: defaultFileName,
                initialDirectory: itineraryFolder.path,
                type: FileType.custom,
                allowedExtensions: ['tt'],
                bytes: Uint8List.fromList(bytes),
              )
            : await FilePicker.saveFile(
                dialogTitle: 'Save Itinerary .tt Container',
                fileName: defaultFileName,
                initialDirectory: itineraryFolder.path,
                type: FileType.custom,
                allowedExtensions: ['tt'],
                bytes: Uint8List.fromList(bytes),
              );
        if (uri != null) {
          userSavedPath = uri.hasScheme && uri.scheme == 'file' ? uri.toFilePath() : uri.path;
        }
      } catch (e) {
        debugPrint('File picker saveFile note: $e');
      }

      final finalPath = (userSavedPath != null && userSavedPath.isNotEmpty)
          ? userSavedPath
          : savedFile.path;

      if (userSavedPath != null && userSavedPath != savedFile.path) {
        try {
          await File(userSavedPath).writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }

      // Open file explorer to show the generated file
      await ItineraryFileManager.openFileInExplorer(finalPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0066FF),
            duration: const Duration(seconds: 5),
            content: Text('Successfully exported "${p.basename(finalPath)}" to ${itineraryFolder.path}'),
            action: SnackBarAction(
              label: 'Open Folder',
              textColor: Colors.white,
              onPressed: () => ItineraryFileManager.openFolderInExplorer(itineraryFolder.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Export failed: $e'),
          ),
        );
      }
    }
  }

  Widget _buildBannerImage(String path) {
    if (path.isEmpty) {
      return _buildFallbackBanner();
    }

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        cacheWidth: 1600,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(),
      );
    }

    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          cacheWidth: 1600,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => _buildFallbackBanner(),
        );
      }
    } catch (_) {}

    return _buildFallbackBanner();
  }

  Widget _buildFallbackBanner() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              controller: _scrollController,
              interactive: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                child: SmoothScroll(
                  controller: _scrollController,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Panoramic Hero Banner

                        RepaintBoundary(child: _buildHeroBanner()),

                        const SizedBox(height: 20),

                        // 2. Information and Documents Trigger Card

                        RepaintBoundary(child: _buildDocumentsTriggerCard()),

                        const SizedBox(height: 24),

                        // 3. Itinerary Day-by-Day Section

                        RepaintBoundary(child: _buildItinerarySection()),

                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroBanner() {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image

            _buildBannerImage(_currentTrip.imagePath),

            // Single high-contrast gradient overlay (combines top/bottom and left contrast in 1 pass)

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // Top Bar: Back button on left, controls on right

            Positioned(
              top: 20,
              left: 24,
              right: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button: "← My Trips"

                  Material(
                    color: Colors.black.withValues(alpha: 0.38),
                    borderRadius: BorderRadius.circular(30),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'My Trips',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Right Controls: Change Banner, 3-dots

                  Row(
                    children: [
                      // Change Banner Button

                      Material(
                        color: Colors.black.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: _showChangeBannerDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    color: Colors.white, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Change Banner',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Three Dots Menu

                      Material(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: const CircleBorder(),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            popupMenuTheme: PopupMenuThemeData(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'Itinerary Options',
                            icon: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const Icon(Icons.more_vert_rounded,
                                  color: Colors.white, size: 18),
                            ),
                            onSelected: (val) {
                              if (val == 'export_tt') {
                                _exportToTtFile();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'export_tt',
                                child: Row(
                                  children: [
                                    Icon(Icons.file_upload_outlined,
                                        size: 18, color: Color(0xFF0066FF)),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text('Export to .tt file',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF0F172A))),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Content: Tagline, Title, Badges, Description, Quote

            Positioned(
              left: 32,
              bottom: 28,
              right: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left details

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tagline

                        Text(
                          _currentTrip.effectiveTagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Title

                        Text(
                          _currentTrip.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 50,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'serif',
                            letterSpacing: -0.8,
                            height: 1.05,
                            shadows: [
                              Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Badges Row

                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Duration

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentTrip.duration,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Date Range

                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.date_range_rounded,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentTrip.dateRange,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Trip Description

                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 850),
                          child: Text(
                            RichDescriptionSyntax.stripTags(
                                _currentTrip.effectiveDescription),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontSize: 13.5,
                              height: 1.45,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Signature Quote on the right

                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: RepaintBoundary(
                      child: Transform.rotate(
                        angle: -0.06,
                        child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Good\nTrips\nBrighter\nStories',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 24,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'serif',
                              height: 1.08,
                              shadows: const [
                                Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsTriggerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _showDocumentsDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              children: [
                // Blue Square Icon

                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: Colors.white, size: 24),
                ),

                const SizedBox(width: 16),

                // Text

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Information and documents',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172554),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _documents.isNotEmpty
                            ? '${_documents.length} document${_documents.length > 1 ? 's' : ''} available. All important information for your trip in one place.'
                            : 'All important information for your trip in one place.',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Chevron

                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItinerarySection() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header

          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itinerary',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF172554)),
                    ),
                    Text(
                      'Your day-by-day plan. Manage days and events below.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                  onPressed: () => _showAddDayDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Day',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    elevation: 0,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Days list

          if (_days.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_month_outlined,
                        size: 44, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    const Text(
                      'No days added yet',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Plan your trip day by day. Click "Add Day" above to get started.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _days.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;

                  final item = _days.removeAt(oldIndex);

                  _days.insert(newIndex, item);
                });

                await ItineraryDatabase.instance.reorderDays(_days);
              },
              itemBuilder: (context, index) {
                final day = _days[index];

                return RepaintBoundary(
                  key: ValueKey(day.id),
                  child: _buildDayCard(day, index),
                );
              },
            ),

                  ],
      ),
    );
  }

  Widget _buildDayCard(TripDayItem day, int index) {
    final eventCount =
        _dayEventCounts[day.id] ?? _dayEventCounts['day_${day.dayNumber}'] ?? 0;

    final subtitle = eventCount > 0
        ? (day.date != null && day.date!.isNotEmpty
            ? '${day.date} · $eventCount ${eventCount == 1 ? "event" : "events"} planned'
            : '$eventCount ${eventCount == 1 ? "event" : "events"} planned')
        : (day.date != null && day.date!.isNotEmpty
            ? '${day.date} · No events yet'
            : 'No events yet');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDayDetails(day),
          hoverColor: const Color(0xFFF8FAFC),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // 6-dot drag handle

                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.drag_indicator_rounded,
                        color: Color(0xFF94A3B8), size: 20),
                  ),
                ),

                const SizedBox(width: 10),

                // Blue Badge for Day

                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'D${day.dayNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Main Info: Day Title and Subtitle

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.title.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                      ),
                      if (day.description != null &&
                          day.description!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          day.description!.trim(),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Edit Button

                IconButton(
                  tooltip: 'Edit Day',
                  onPressed: () => _showAddDayDialog(dayToEdit: day),
                  icon: const Icon(Icons.edit_outlined,
                      size: 19, color: Color(0xFF64748B)),
                  splashRadius: 18,
                ),

                // 3-dot Menu

                PopupMenuButton<String>(
                  tooltip: 'Options',
                  icon: const Icon(Icons.more_horiz_rounded,
                      size: 20, color: Color(0xFF64748B)),
                  splashRadius: 18,
                  onSelected: (val) {
                    if (val == 'edit') _showAddDayDialog(dayToEdit: day);

                    if (val == 'delete') _deleteDay(day);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 16, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Edit Day', style: TextStyle(fontSize: 13)),
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
                          Text('Delete Day',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 4),

                // Chevron indicating card can be clicked to open details

                const Icon(Icons.chevron_right_rounded,
                    size: 22, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
