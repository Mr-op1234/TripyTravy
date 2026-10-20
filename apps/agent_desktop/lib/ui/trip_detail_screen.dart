import 'dart:io';
import 'package:flutter/material.dart';
import '../data/itinerary_database.dart';
import 'dialogs/change_banner_dialog.dart';
import 'dialogs/documents_dialog.dart';
import 'dialogs/event_editor_dialog.dart';
import 'widgets/smooth_scroll.dart';

class TripDetailScreen extends StatefulWidget {
  final DestinationItem item;
  final List<TripEventItem>? initialEvents;
  final List<TripDocumentItem>? initialDocuments;

  const TripDetailScreen({
    super.key,
    required this.item,
    this.initialEvents,
    this.initialDocuments,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late DestinationItem _currentTrip;
  late final ScrollController _scrollController;
  List<TripEventItem> _events = [];
  List<TripDocumentItem> _documents = [];
  final Set<String> _expandedEventIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _currentTrip = widget.item;
    if (widget.initialEvents != null) {
      _events = List.from(widget.initialEvents!);
      _documents = List.from(widget.initialDocuments ?? []);
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
    final updatedTrip = await ItineraryDatabase.instance.getItineraryById(_currentTrip.id);
    final events = await ItineraryDatabase.instance.getEventsForItinerary(_currentTrip.id);
    final docs = await ItineraryDatabase.instance.getDocumentsForItinerary(_currentTrip.id);

    if (mounted) {
      setState(() {
        if (updatedTrip != null) _currentTrip = updatedTrip;
        _events = events;
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  void _toggleExpandAll() {
    setState(() {
      if (_expandedEventIds.length == _events.length) {
        _expandedEventIds.clear();
      } else {
        _expandedEventIds.addAll(_events.map((e) => e.id));
      }
    });
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedEventIds.contains(id)) {
        _expandedEventIds.remove(id);
      } else {
        _expandedEventIds.add(id);
      }
    });
  }

  void _openMaps(String location) {
    if (location.isEmpty) return;
    final encoded = Uri.encodeComponent(location);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encoded';
    try {
      if (Platform.isWindows) {
        Process.run('explorer.exe', [url]);
      } else {
        Process.run('open', [url]);
      }
    } catch (_) {}
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

  void _showEventEditor({TripEventItem? eventToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EventEditorDialog(
        itineraryId: _currentTrip.id,
        eventToEdit: eventToEdit,
        onSave: (savedEvent) async {
          if (eventToEdit != null) {
            await ItineraryDatabase.instance.updateEvent(savedEvent);
          } else {
            await ItineraryDatabase.instance.insertEvent(savedEvent);
          }
          _loadTripData();
        },
      ),
    );
  }

  void _showDeleteEventDialog(TripEventItem event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text('Delete Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${event.title}" from this itinerary?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ItineraryDatabase.instance.deleteEvent(event.id);
              _loadTripData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete Event', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImage(String path) {
    if (path.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
      );
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackBanner());
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackBanner());
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackBanner());
    }
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
    final allExpanded = _events.isNotEmpty && _expandedEventIds.length == _events.length;

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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                        _buildItinerarySection(allExpanded),
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
            color: const Color(0xFF0F172A).withValues(alpha: 0.22),
            blurRadius: 36,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            _buildBannerImage(_currentTrip.imagePath),

            // Vertical gradient for top/bottom contrast
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.20),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Horizontal subtle gradient for left alignment
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.65),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 0.6, 1.0],
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'My Trips',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: Colors.white, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Change Banner',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5),
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          child: PopupMenuButton<String>(
                            tooltip: 'Banner Options',
                            icon: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                            ),
                            onSelected: (val) {
                              if (val == 'banner') _showChangeBannerDialog();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'banner',
                                child: Row(
                                  children: [
                                    Icon(Icons.image_outlined, size: 18, color: Color(0xFF334155)),
                                    SizedBox(width: 10),
                                    Text('Change Banner', style: TextStyle(fontSize: 13)),
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
                              Shadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 3)),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentTrip.duration,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                            // Date Range
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.date_range_rounded, color: Colors.white, size: 13),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentTrip.dateRange,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
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
                            _currentTrip.effectiveDescription,
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
                                Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 2)),
                              ],
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
                  child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
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
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),

                // Chevron
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItinerarySection(bool allExpanded) {
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
                child: const Icon(Icons.map_rounded, color: Color(0xFF2563EB), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itinerary',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF172554)),
                    ),
                    Text(
                      'Your day-by-day plan. Expand each event for more details.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (_events.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _toggleExpandAll,
                  icon: Icon(
                    allExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF334155),
                  ),
                  label: Text(
                    allExpanded ? 'Collapse All' : 'Expand All',
                    style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Events list
          if (_events.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 44, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 10),
                    const Text(
                      'No events added yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Plan flights, accommodation, dining, and scenic activities below.',
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
              itemCount: _events.length,
              onReorder: (oldIndex, newIndex) async {
                setState(() {
                  if (oldIndex < newIndex) newIndex -= 1;
                  final item = _events.removeAt(oldIndex);
                  _events.insert(newIndex, item);
                });
                await ItineraryDatabase.instance.reorderEvents(_events);
              },
              itemBuilder: (context, index) {
                final event = _events[index];
                final isExpanded = _expandedEventIds.contains(event.id);
                return RepaintBoundary(
                  key: ValueKey(event.id),
                  child: _buildEventCard(event, index, isExpanded),
                );
              },
            ),

          const SizedBox(height: 16),

          // "+ Add Event" Dashed Card
          _buildAddEventDashedCard(),
        ],
      ),
    );
  }

  Widget _buildEventCard(TripEventItem event, int index, bool isExpanded) {
    final relatedDocs = _documents.where((d) => d.eventId == event.id).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isExpanded ? const Color(0xFFCBD7EA) : const Color(0xFFE6ECF4)),
        boxShadow: [
          BoxShadow(
            color: isExpanded ? const Color(0xFF172554).withValues(alpha: 0.08) : const Color(0xFF101828).withValues(alpha: 0.03),
            blurRadius: isExpanded ? 16 : 4,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsed Header Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 6-dot Drag Handle
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.drag_indicator_rounded, color: Color(0xFF94A3B8), size: 20),
                  ),
                ),
                const SizedBox(width: 8),

                // Thumbnail Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 78,
                    height: 52,
                    color: const Color(0xFFF1F5F9),
                    child: event.coverImage.isNotEmpty
                        ? (event.coverImage.startsWith('assets/')
                            ? Image.asset(event.coverImage, fit: BoxFit.cover)
                            : Image.file(File(event.coverImage), fit: BoxFit.cover))
                        : const Icon(Icons.landscape_rounded, color: Color(0xFF94A3B8), size: 26),
                  ),
                ),
                const SizedBox(width: 14),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF172554),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(event.eventDate, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          if (event.startTime != null && event.endTime != null) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            Text('${event.startTime} - ${event.endTime}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                          ],
                          if (event.duration.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            Text(event.duration, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                          if (event.location.isNotEmpty) ...[
                            const Text(' • ', style: TextStyle(color: Color(0xFF94A3B8))),
                            InkWell(
                              onTap: () => _openMaps(event.location),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 2),
                                  Text(
                                    event.location,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF2563EB),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF2563EB)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions: Edit, Delete, Chevron
                IconButton(
                  tooltip: 'Edit Event',
                  onPressed: () => _showEventEditor(eventToEdit: event),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF475569)),
                  splashRadius: 18,
                ),
                IconButton(
                  tooltip: 'Delete Event',
                  onPressed: () => _showDeleteEventDialog(event),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                  splashRadius: 18,
                ),
                IconButton(
                  tooltip: isExpanded ? 'Collapse' : 'Expand Details',
                  onPressed: () => _toggleExpand(event.id),
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF475569),
                    size: 22,
                  ),
                  splashRadius: 18,
                ),
              ],
            ),
          ),

          // Expanded Drawer
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (event.description.isNotEmpty) ...[
                    Row(
                      children: const [
                        Icon(Icons.notes_rounded, size: 16, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Description',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF172554)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3-Column Layout: Photos, Notes, Documents
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Photos
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_outlined, size: 15, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  'Photos (${event.photos.length})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF172554)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (event.photos.isEmpty)
                              const Text('No photos added.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: event.photos.map((p) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(File(p), width: 80, height: 55, fit: BoxFit.cover),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Column 2: Additional Notes
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                                SizedBox(width: 6),
                                Text(
                                  'Additional Notes',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF172554)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (event.notes.isEmpty)
                              const Text('No tips or notes recorded.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: event.notes.map((n) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                        Expanded(
                                          child: Text(n, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155))),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Column 3: Event Documents
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.folder_outlined, size: 15, color: Color(0xFF2563EB)),
                                const SizedBox(width: 6),
                                Text(
                                  'Documents (${relatedDocs.length})',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF172554)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (relatedDocs.isEmpty)
                              const Text('No attached documents.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: relatedDocs.map((doc) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_rounded, size: 14, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            doc.title,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddEventDashedCard() {
    return InkWell(
      onTap: () => _showEventEditor(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFDFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFA9C3F2),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+ Add Event',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF172554),
                  ),
                ),
                Text(
                  'Append a new activity, destination, or milestone to this trip\'s itinerary.',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
