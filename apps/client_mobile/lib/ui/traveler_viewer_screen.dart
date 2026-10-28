import 'package:flutter/material.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';
import 'widgets/trip_card_widget.dart';

/// Primary controller for the Traveler viewer application.
/// Manages loaded trip itinerary, timeline calculations, persistent checklist, and media resolution.
class TravelerViewerController {
  final MobileDiContainer di;
  TripPackage? loadedTrip;
  TripChecklistState? _currentChecklist;
  TravelerTimelineService? _timelineService;

  TravelerViewerController({required this.di});

  TravelerTimelineService? get timeline => _timelineService;
  TripChecklistState? get checklist => _currentChecklist;

  /// Loads the active trip from local persistence.
  Future<TripPackage?> loadActiveTrip() async {
    final trip = await di.tripManager.getActiveTrip();
    if (trip != null) {
      loadedTrip = trip;
      _timelineService = TravelerTimelineService(trip: trip);
      _currentChecklist =
          await di.checklistRepository.getChecklistForTrip(trip.tripId);
    }
    return trip;
  }

  /// Strictly offline-first schedule viewer; imports a .ttrv container file and sets active.
  Future<TripPackage> openTtFileStream(List<int> rawBytes, {String? pin}) async {
    final trip =
        await di.tripManager.importTripFromContainer(rawBytes, userPin: pin);
    loadedTrip = trip;
    _timelineService = TravelerTimelineService(trip: trip);
    _currentChecklist =
        await di.checklistRepository.getChecklistForTrip(trip.tripId);
    return trip;
  }

  /// Toggles checklist item and persists immediately to disk.
  Future<TripChecklistState> toggleLocalChecklistItem(
      String itemId, bool checked) async {
    if (loadedTrip == null) {
      throw StateError('Cannot toggle checklist without an active trip loaded');
    }
    final updated = await di.tripManager
        .toggleChecklistItem(loadedTrip!.tripId, itemId, checked);
    _currentChecklist = updated;
    return updated;
  }

  /// Adds a custom item to the traveler's checklist.
  Future<TripChecklistState> addCustomChecklistItem(String title,
      {ChecklistCategory category = ChecklistCategory.misc}) async {
    if (loadedTrip == null) {
      throw StateError('Cannot add checklist item without an active trip loaded');
    }
    final item = TravelerChecklistItem(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      category: category,
      isCustom: true,
      isChecked: false,
    );
    final updated =
        await di.tripManager.addChecklistItem(loadedTrip!.tripId, item);
    _currentChecklist = updated;
    return updated;
  }

  /// Checks if a checklist item is checked.
  bool isChecklistItemChecked(String itemId, {bool defaultVal = false}) {
    if (_currentChecklist == null) return defaultVal;
    final item = _currentChecklist!.items.firstWhere(
      (i) => i.id == itemId,
      orElse: () =>
          TravelerChecklistItem(id: itemId, title: '', isChecked: defaultVal),
    );
    return item.isChecked;
  }

  /// Resolves raw attachment bytes by SHA-256 hash.
  Future<List<int>?> getAttachmentBlob(String sha256Checksum) {
    return di.attachmentStorage.readBlobBySha256(sha256Checksum);
  }

  /// Resolves attachment local filesystem path for direct image/PDF rendering.
  Future<String?> getAttachmentFilePath(String sha256Checksum) {
    return di.attachmentStorage.getBlobPath(sha256Checksum);
  }
}

/// Detailed itinerary screen for the mobile client matching the reference UI.
class TravelerItineraryViewScreen extends StatefulWidget {
  final MobileDiContainer di;
  final TripPackage trip;
  final String? coverImageUrl;

  const TravelerItineraryViewScreen({
    super.key,
    required this.di,
    required this.trip,
    this.coverImageUrl,
  });

  @override
  State<TravelerItineraryViewScreen> createState() =>
      _TravelerItineraryViewScreenState();
}

class _TravelerItineraryViewScreenState
    extends State<TravelerItineraryViewScreen> {
  TripChecklistState? _checklist;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final chk = await widget.di.checklistRepository
        .getChecklistForTrip(widget.trip.tripId);
    if (mounted) {
      setState(() => _checklist = chk);
    }
  }

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded,
                    color: Color(0xFF0D2356)),
                title: const Text('Traveler Packing Checklist',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _checklist != null
                      ? '${((_checklist!.progressPercentage) * 100).round()}% complete (${_checklist!.totalCount - _checklist!.completedCount} pending)'
                      : 'Pack essentials and travel items',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openChecklistModal(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined,
                    color: Color(0xFF2563EB)),
                title: const Text('Information and documents',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('View all vouchers, tickets, and notes'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openInformationAndDocuments(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChecklistModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Traveler Checklist',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D2356),
                          ),
                        ),
                        if (_checklist != null)
                          Text(
                            '${((_checklist!.progressPercentage) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D2356),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_checklist != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _checklist!.progressPercentage,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0D2356)),
                          minHeight: 6,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _checklist == null || _checklist!.items.isEmpty
                          ? const Center(
                              child: Text(
                                'No checklist items found.',
                                style: TextStyle(color: Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _checklist!.items.length,
                              itemBuilder: (context, index) {
                                final item = _checklist!.items[index];
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeColor: const Color(0xFF0D2356),
                                  title: Text(
                                    item.title,
                                    style: TextStyle(
                                      decoration: item.isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isChecked
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF1E293B),
                                    ),
                                  ),
                                  value: item.isChecked,
                                  onChanged: (val) async {
                                    if (val != null) {
                                      final updated = await widget.di.tripManager
                                          .toggleChecklistItem(
                                              widget.trip.tripId, item.id, val);
                                      if (mounted) {
                                        setState(() => _checklist = updated);
                                        setModalState(() => _checklist = updated);
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openInformationAndDocuments(BuildContext context) {
    final docs = widget.trip.documents;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_outlined,
                          color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Information and documents',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'All important vouchers, tickets, and notes from the agent side.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: docs.isEmpty
                      ? const Center(
                          child: Text(
                            'No documents or vouchers attached to this trip.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB)
                                          .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.description_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                doc.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.5,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            if (doc.docType.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE0E7FF),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  doc.docType.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF3730A3),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (doc.description.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            doc.description,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFF475569),
                                            ),
                                          ),
                                        ],
                                        if (doc.fileName.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            '${doc.fileName}${doc.fileSize.isNotEmpty ? " • ${doc.fileSize}" : ""}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                        if (doc.locationName != null &&
                                            doc.locationName!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined,
                                                  size: 13,
                                                  color: Color(0xFF64748B)),
                                              const SizedBox(width: 3),
                                              Expanded(
                                                child: Text(
                                                  doc.locationName!,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDayDetails(BuildContext context, ItineraryDay day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_outlined,
                          color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day ${day.dayNumber}: ${day.title}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          if (day.dateIso8601.isNotEmpty)
                            Text(
                              day.dateIso8601,
                              style: const TextStyle(
                                  fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (day.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      day.description,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF334155), height: 1.35),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Events & Schedule',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: day.events.isEmpty
                      ? const Center(
                          child: Text(
                            'No schedule events planned for this day yet.',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: day.events.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final ev = day.events[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.place_outlined,
                                      color: Color(0xFF2563EB),
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          ev.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (ev.note?.markdownBody.isNotEmpty ??
                                            false) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            ev.note!.markdownBody,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final displayTitle = trip.title.toLowerCase() == 'osaka'
        ? 'Osaka, Japan'
        : trip.title;
    final duration = calculateTripDuration(trip);
    final dateRange =
        formatTripDateRange(trip.startDateIso8601, trip.endDateIso8601);

    // The description written in the banner is the description of the trip
    final tripDescription = trip.subtitle.isNotEmpty
        ? trip.subtitle
        : 'A vibrant city known for its historic landmarks, delicious street food, and energetic nightlife.';

    final docCount = trip.documents.length;
    final docSubtitle = docCount > 0
        ? '$docCount document${docCount > 1 ? "s" : ""} available. View and manage all your trip documents in one place.'
        : 'View and manage all your trip documents in one place.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Panoramic Hero Banner
          SliverToBoxAdapter(
            child: SizedBox(
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover Image
                  _buildCoverImage(),

                  // Multi-stop Gradient Overlay for Crisp Readability
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.15, 0.55, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.30),
                          Colors.black.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),

                  // Top Action Buttons (< and ...)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Circular dark back button
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chevron_left_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                            ),

                            // Circular dark options button
                            InkWell(
                              onTap: () => _showMoreOptions(context),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Banner Content (Title, Description, Badge)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Trip Title (e.g. Osaka, Japan)
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Trip Description written in the banner
                        Text(
                          tripDescription,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Pill / Badge (Calendar | Days | Date range)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 13.5,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                duration,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '|',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  dateRange,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Body Content Below Banner
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // NOTE: "About this trip" section is completely removed as requested!

                // Information and documents Section
                Container(
                  margin: const EdgeInsets.only(bottom: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openInformationAndDocuments(context),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.folder_outlined,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Information and documents',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    docSubtitle,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF94A3B8),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // "Your Itinerary" Heading
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 12),
                  child: Text(
                    'Your Itinerary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),

                // Day Wise Cards List
                if (trip.days.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'No itinerary days added yet.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ...trip.days.map((day) {
                    final dayTitle = day.title.toLowerCase().startsWith('day')
                        ? day.title
                        : 'Day ${day.dayNumber}: ${day.title}';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openDayDetails(context, day),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Calendar outline badge
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5FB),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today_outlined,
                                    color: Color(0xFF4F46E5),
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dayTitle,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (day.description.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          day.description,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF64748B),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 22,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImage() {
    if (widget.coverImageUrl != null &&
        widget.coverImageUrl!.startsWith('http')) {
      return Image.network(
        widget.coverImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/japan.png',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFF0F172A),
          ),
        ),
      );
    }

    return Image.asset(
      'assets/images/japan.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2356), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}
