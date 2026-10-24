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

/// Detailed itinerary and checklist screen for a selected trip package
class TravelerItineraryViewScreen extends StatefulWidget {
  final MobileDiContainer di;
  final TripPackage trip;

  const TravelerItineraryViewScreen({
    super.key,
    required this.di,
    required this.trip,
  });

  @override
  State<TravelerItineraryViewScreen> createState() =>
      _TravelerItineraryViewScreenState();
}

class _TravelerItineraryViewScreenState
    extends State<TravelerItineraryViewScreen> {
  TripChecklistState? _checklist;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    setState(() => _isLoading = true);
    final chk = await widget.di.checklistRepository
        .getChecklistForTrip(widget.trip.tripId);
    if (mounted) {
      setState(() {
        _checklist = chk;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItem(String itemId, bool checked) async {
    final updated = await widget.di.tripManager
        .toggleChecklistItem(widget.trip.tripId, itemId, checked);
    if (mounted) {
      setState(() => _checklist = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final duration = calculateTripDuration(trip);
    final dateRange =
        formatTripDateRange(trip.startDateIso8601, trip.endDateIso8601);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF0D2356), size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            trip.title,
            style: const TextStyle(
              color: Color(0xFF0D2356),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          bottom: const TabBar(
            labelColor: Color(0xFF0D2356),
            unselectedLabelColor: Color(0xFF94A3B8),
            indicatorColor: Color(0xFF0D2356),
            tabs: [
              Tab(text: 'Itinerary Days'),
              Tab(text: 'Traveler Checklist'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Itinerary Days
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5FB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Color(0xFF0D2356), size: 28),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duration,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0D2356),
                            ),
                          ),
                          Text(
                            dateRange,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (trip.days.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'No day-by-day events added yet.',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  )
                else
                  ...trip.days.map((day) => Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D2356),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${day.dayNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Color(0xFF0D2356),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    day.dateIso8601,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (day.events.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '${day.events.length} schedule events',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),

            // Tab 2: Traveler Checklist
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_checklist != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Preparation Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF0D2356),
                              ),
                            ),
                            Text(
                              '${((_checklist!.progressPercentage) * 100).round()}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D2356),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _checklist!.progressPercentage,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF0D2356)),
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ..._checklist!.items.map(
                          (item) => CheckboxListTile(
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
                            onChanged: (val) {
                              if (val != null) {
                                _toggleItem(item.id, val);
                              }
                            },
                          ),
                        ),
                      ] else ...[
                        const Center(
                          child: Text('No checklist found for this trip'),
                        ),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
