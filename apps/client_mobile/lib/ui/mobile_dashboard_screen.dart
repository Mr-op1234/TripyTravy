import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';
import 'completed_trips_screen.dart';
import 'traveler_viewer_screen.dart';
import 'widgets/empty_trips_view.dart';
import 'widgets/import_tt_dialog.dart';
import 'widgets/trip_card_widget.dart';

/// Inspiration demo trips matching the reference screenshot exactly
final List<TripPackage> kInspirationDemoTrips = [
  const TripPackage(
    tripId: 'trip_osaka_demo',
    title: 'Osaka',
    subtitle: 'Your journeys across the World',
    destinationTags: ['Japan', 'Osaka', 'Kansai'],
    startDateIso8601: '2025-05-20',
    endDateIso8601: '2025-05-23',
    primaryTimezoneIana: 'Asia/Tokyo',
    days: [
      ItineraryDay(
        dayNumber: 1,
        dateIso8601: '2025-05-20',
        title: 'Arrival in Osaka & Dotonbori',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 2,
        dateIso8601: '2025-05-21',
        title: 'Osaka Castle & Shinsekai',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 3,
        dateIso8601: '2025-05-22',
        title: 'Universal Studios Japan',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 4,
        dateIso8601: '2025-05-23',
        title: 'Kuromon Market & Departure',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
    ],
  ),
  const TripPackage(
    tripId: 'trip_tokyo_demo',
    title: 'Tokyo',
    subtitle: 'Your journeys across the World',
    destinationTags: ['Japan', 'Tokyo', 'Kanto'],
    startDateIso8601: '2025-05-24',
    endDateIso8601: '2025-05-28',
    primaryTimezoneIana: 'Asia/Tokyo',
    days: [
      ItineraryDay(
        dayNumber: 1,
        dateIso8601: '2025-05-24',
        title: 'Shinjuku & Shibuya Crossing',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 2,
        dateIso8601: '2025-05-25',
        title: 'Asakusa Senso-ji & Akihabara',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 3,
        dateIso8601: '2025-05-26',
        title: 'Ginza & Roppongi Hills',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 4,
        dateIso8601: '2025-05-27',
        title: 'Tokyo Tower & Odaiba',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 5,
        dateIso8601: '2025-05-28',
        title: 'Harajuku & Meiji Shrine',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
    ],
  ),
  const TripPackage(
    tripId: 'trip_kyoto_demo',
    title: 'Kyoto',
    subtitle: 'Your journeys across the World',
    destinationTags: ['Japan', 'Kyoto', 'Kansai'],
    startDateIso8601: '2025-05-29',
    endDateIso8601: '2025-06-01',
    primaryTimezoneIana: 'Asia/Tokyo',
    days: [
      ItineraryDay(
        dayNumber: 1,
        dateIso8601: '2025-05-29',
        title: 'Fushimi Inari-taisha & Gion',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 2,
        dateIso8601: '2025-05-30',
        title: 'Arashiyama Bamboo Grove',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 3,
        dateIso8601: '2025-05-31',
        title: 'Kinkaku-ji Golden Pavilion',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
      ItineraryDay(
        dayNumber: 4,
        dateIso8601: '2025-06-01',
        title: 'Kiyomizu-dera & Departure',
        primaryTimezoneIana: 'Asia/Tokyo',
      ),
    ],
  ),
];

/// Cover photos matching Osaka Castle, Tokyo Tower sunset, and Kyoto pagodas
final Map<String, String> kDemoTripImages = {
  'trip_osaka_demo':
      'https://images.unsplash.com/photo-1590559899731-a3f30b2c55e9?auto=format&fit=crop&w=1200&q=80',
  'trip_tokyo_demo':
      'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
  'trip_kyoto_demo':
      'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=1200&q=80',
};

class MobileDashboardScreen extends StatefulWidget {
  final MobileDiContainer di;
  final Future<List<PlatformFile>> Function()? filePickerOverride;
  final bool autoSeedDemoTripsIfEmpty;

  const MobileDashboardScreen({
    super.key,
    required this.di,
    this.filePickerOverride,
    this.autoSeedDemoTripsIfEmpty = true,
  });

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<TripPackage> _trips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    setState(() => _isLoading = true);
    await _loadTrips();

    // If initial launch and empty, seed the inspiration demo trips
    if (_trips.isEmpty && widget.autoSeedDemoTripsIfEmpty) {
      await _loadInspirationDemoTrips();
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTrips() async {
    final list = await widget.di.tripRepository.listAllTrips();
    if (mounted) {
      setState(() {
        _trips = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInspirationDemoTrips() async {
    setState(() => _isLoading = true);
    for (final trip in kInspirationDemoTrips) {
      await widget.di.tripRepository.saveTrip(trip);
    }
    await _loadTrips();
  }

  Future<void> _clearAllTrips() async {
    setState(() => _isLoading = true);
    for (final t in _trips) {
      await widget.di.tripRepository.deleteTrip(t.tripId);
    }
    await _loadTrips();
  }

  Future<void> _markTripCompleted(TripPackage trip) async {
    final updated = trip.copyWith(isCompleted: true);
    await widget.di.tripRepository.saveTrip(updated);
    await _loadTrips();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked "${trip.title}" as complete'),
        backgroundColor: const Color(0xFF0D2356),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.amberAccent,
          onPressed: () async {
            await widget.di.tripRepository
                .saveTrip(trip.copyWith(isCompleted: false));
            await _loadTrips();
          },
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteTrip(TripPackage trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Trip',
          style: TextStyle(
            color: Color(0xFF0D2356),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${trip.title}"?',
          style: const TextStyle(color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.di.tripRepository.deleteTrip(trip.tripId);
      await _loadTrips();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${trip.title}"'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openImportDialog() async {
    final imported = await showImportTtFileDialog(
      context: context,
      tripManager: widget.di.tripManager,
      filePickerOverride: widget.filePickerOverride,
    );

    if (imported != null && mounted) {
      await _loadTrips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported "${imported.title}" itinerary'),
          backgroundColor: const Color(0xFF0D2356),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openTripDetail(TripPackage trip) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TravelerItineraryViewScreen(
          di: widget.di,
          trip: trip,
        ),
      ),
    );
  }

  void _openCompletedTripsScreen() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => CompletedTripsScreen(
              di: widget.di,
              onTripsChanged: _loadTrips,
            ),
          ),
        )
        .then((_) => _loadTrips());
  }

  @override
  Widget build(BuildContext context) {
    final activeTrips = _trips.where((t) => !t.isCompleted).toList();
    final completedTrips = _trips.where((t) => t.isCompleted).toList();

    final subtitleText = activeTrips.isNotEmpty
        ? (activeTrips.first.subtitle.isNotEmpty
            ? activeTrips.first.subtitle
            : 'Your journeys across the World')
        : 'Your personal travel companion';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(activeCount: activeTrips.length, completedCount: completedTrips.length),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top App Bar / Header matching Inspiration UI
                _buildHeader(subtitleText),

                // Content Area: Either the Cards List or the Minimalistic Empty State
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Color(0xFF0D2356)),
                          ),
                        )
                      : activeTrips.isEmpty
                          ? EmptyTripsView(onImportTap: _openImportDialog)
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                              itemCount: activeTrips.length,
                              itemBuilder: (context, index) {
                                final trip = activeTrips[index];
                                final imageUrl = kDemoTripImages[trip.tripId];

                                return TripCardWidget(
                                  trip: trip,
                                  imageUrl: imageUrl,
                                  onTap: () => _openTripDetail(trip),
                                  onLongPress: () => _showTripOptionsDialog(trip),
                                  onToggleComplete: () => _markTripCompleted(trip),
                                  onDelete: () => _confirmAndDeleteTrip(trip),
                                );
                              },
                            ),
                ),
              ],
            ),

            // Completed thing in the bottom-right corner
            Positioned(
              right: 18,
              bottom: 16,
              child: _buildCompletedPillButton(completedTrips.length),
            ),
          ],
        ),
      ),
      // Centered '+' Button matching Inspiration UI
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D2356).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF0D2356),
          elevation: 0,
          shape: const CircleBorder(),
          onPressed: _openImportDialog,
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedPillButton(int completedCount) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('completed_bottom_right_button'),
        onTap: _openCompletedTripsScreen,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0D2356),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2356).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 7),
              const Text(
                'Completed',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
              if (completedCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completedCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String subtitleText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hamburger menu icon
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Color(0xFF0D2356),
              size: 30,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            splashRadius: 24,
            tooltip: 'Navigation Menu',
          ),
          const SizedBox(width: 8),
          // App Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tripy Travy',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D2356),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF5A6882),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer({required int activeCount, required int completedCount}) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: const Color(0xFFF8FAFD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D2356),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tripy Travy',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D2356),
                    ),
                  ),
                  const Text(
                    'Mobile Itinerary Companion',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined,
                  color: Color(0xFF0D2356)),
              title: const Text('Import .tt File'),
              onTap: () {
                Navigator.of(context).pop();
                _openImportDialog();
              },
            ),
            ListTile(
              key: const Key('drawer_completed_trips'),
              leading: const Icon(
                Icons.check_circle_outline_rounded,
                color: Color(0xFF0D2356),
              ),
              title: const Text('Completed Trips'),
              trailing: completedCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D2356),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$completedCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                Navigator.of(context).pop();
                _openCompletedTripsScreen();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded,
                  color: Color(0xFF0D2356)),
              title: const Text('Reset Inspiration Trips (Osaka, Tokyo, Kyoto)'),
              subtitle: const Text('Restore reference mockup trips'),
              onTap: () {
                Navigator.of(context).pop();
                _loadInspirationDemoTrips();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined,
                  color: Colors.redAccent),
              title: const Text('Clear All Trips'),
              subtitle: const Text('View empty state & rounded arrow'),
              onTap: () {
                Navigator.of(context).pop();
                _clearAllTrips();
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Active: $activeCount · Completed: $completedCount',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTripOptionsDialog(TripPackage trip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                trip.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D2356),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.visibility_outlined,
                    color: Color(0xFF0D2356)),
                title: const Text('View Itinerary Days'),
                onTap: () {
                  Navigator.of(bottomCtx).pop();
                  _openTripDetail(trip);
                },
              ),
              ListTile(
                leading: Icon(
                  trip.isCompleted
                      ? Icons.replay_rounded
                      : Icons.check_circle_outline_rounded,
                  color: const Color(0xFF0D2356),
                ),
                title: Text(
                    trip.isCompleted ? 'Mark as active' : 'Mark as complete'),
                onTap: () async {
                  Navigator.of(bottomCtx).pop();
                  if (trip.isCompleted) {
                    await widget.di.tripRepository
                        .saveTrip(trip.copyWith(isCompleted: false));
                  } else {
                    await widget.di.tripRepository
                        .saveTrip(trip.copyWith(isCompleted: true));
                  }
                  await _loadTrips();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Trip'),
                onTap: () async {
                  Navigator.of(bottomCtx).pop();
                  await _confirmAndDeleteTrip(trip);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
