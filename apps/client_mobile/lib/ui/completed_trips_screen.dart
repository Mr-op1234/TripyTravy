import 'package:flutter/material.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';
import 'mobile_dashboard_screen.dart';
import 'traveler_viewer_screen.dart';
import 'widgets/trip_card_widget.dart';

class CompletedTripsScreen extends StatefulWidget {
  final MobileDiContainer di;
  final VoidCallback? onTripsChanged;

  const CompletedTripsScreen({
    super.key,
    required this.di,
    this.onTripsChanged,
  });

  @override
  State<CompletedTripsScreen> createState() => _CompletedTripsScreenState();
}

class _CompletedTripsScreenState extends State<CompletedTripsScreen> {
  List<TripPackage> _completedTrips = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletedTrips();
  }

  Future<void> _loadCompletedTrips() async {
    setState(() => _isLoading = true);
    final all = await widget.di.tripRepository.listAllTrips();
    if (mounted) {
      setState(() {
        _completedTrips = all.where((t) => t.isCompleted).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsActive(TripPackage trip) async {
    final updated = trip.copyWith(isCompleted: false);
    await widget.di.tripRepository.saveTrip(updated);
    widget.onTripsChanged?.call();
    await _loadCompletedTrips();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Restored "${trip.title}" to active trips'),
        backgroundColor: const Color(0xFF0D2356),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _confirmAndDelete(TripPackage trip) async {
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
      widget.onTripsChanged?.call();
      await _loadCompletedTrips();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0D2356), size: 22),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back to Dashboard',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Completed Trips',
              style: TextStyle(
                color: Color(0xFF0D2356),
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (!_isLoading)
              Text(
                '${_completedTrips.length} ${_completedTrips.length == 1 ? "journey" : "journeys"} completed',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D2356)),
                ),
              )
            : _completedTrips.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    itemCount: _completedTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _completedTrips[index];
                      final imageUrl = kDemoTripImages[trip.tripId];

                      return TripCardWidget(
                        trip: trip,
                        imageUrl: imageUrl,
                        onTap: () => _openTripDetail(trip),
                        onToggleComplete: () => _markAsActive(trip),
                        onDelete: () => _confirmAndDelete(trip),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                size: 46,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Completed Trips Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2356),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When you finish a journey, tap the three dots on its card and select "Mark as complete" to archive it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
