import 'package:flutter/material.dart';
import 'package:tripytravy_core/tripytravy_core.dart';

/// Formats date string range into "MMM dd, yyyy – MMM dd, yyyy"
String formatTripDateRange(String? startIso, String? endIso) {
  if (startIso == null || startIso.isEmpty) return 'Dates TBA';
  try {
    final start = DateTime.parse(startIso);
    final end = (endIso != null && endIso.isNotEmpty)
        ? DateTime.parse(endIso)
        : start;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final startStr = '${months[start.month - 1]} ${start.day}, ${start.year}';
    final endStr = '${months[end.month - 1]} ${end.day}, ${end.year}';
    if (startStr == endStr) return startStr;
    return '$startStr – $endStr';
  } catch (_) {
    return '$startIso – ${endIso ?? ""}';
  }
}

/// Calculates "X Days" based on start and end dates or days list
String calculateTripDuration(TripPackage trip) {
  if (trip.days.isNotEmpty) {
    final count = trip.days.length;
    return '$count ${count == 1 ? "Day" : "Days"}';
  }
  try {
    final start = DateTime.parse(trip.startDateIso8601);
    final end = DateTime.parse(trip.endDateIso8601);
    final diff = end.difference(start).inDays + 1;
    final count = diff <= 0 ? 1 : diff;
    return '$count ${count == 1 ? "Day" : "Days"}';
  } catch (_) {
    return '1 Day';
  }
}

/// Full-bleed panoramic trip card matching the Tripy Travy mobile inspiration design.
class TripCardWidget extends StatelessWidget {
  final TripPackage trip;
  final String? imageUrl;
  final String fallbackAsset;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const TripCardWidget({
    super.key,
    required this.trip,
    this.imageUrl,
    this.fallbackAsset = 'assets/images/japan.png',
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final durationText = calculateTripDuration(trip);
    final dateRangeText = formatTripDateRange(
      trip.startDateIso8601,
      trip.endDateIso8601,
    );

    return Container(
      height: 215,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background cover image
                _buildCoverImage(),

                // Deep gradient overlay at the bottom for crisp legibility
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.25, 0.60, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),

                // Card details pinned at bottom-left
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Big bold destination / trip title
                      Text(
                        trip.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Duration text ("4 Days")
                      Text(
                        durationText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Calendar date span row
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              dateRangeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          fallbackAsset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF1E293B),
          ),
        ),
      );
    }

    return Image.asset(
      fallbackAsset,
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
