import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tripytravy_core/tripytravy_core.dart';
import '../di/mobile_di_container.dart';

/// Styling and icon resolution for event categories across client mobile.
class EventCategoryStyle {
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final String label;

  const EventCategoryStyle({
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.label,
  });

  static EventCategoryStyle resolve(ItineraryEvent ev) {
    final cat = ev.category.toLowerCase();
    final sub = ev.subCategory.toLowerCase();
    final title = ev.title.toLowerCase();

    if (cat.contains('flight') ||
        sub.contains('flight') ||
        cat.contains('transport') ||
        sub.contains('drive') ||
        sub.contains('train') ||
        sub.contains('bus') ||
        sub.contains('transfer') ||
        cat.contains('departure') ||
        sub.contains('departure')) {
      final isDeparture = cat.contains('departure') || sub.contains('departure');
      final isFlight = cat.contains('flight') || sub.contains('flight') || title.contains('flight');
      return EventCategoryStyle(
        icon: isFlight || isDeparture ? Icons.flight_takeoff_rounded : Icons.directions_transit_rounded,
        primaryColor: const Color(0xFFE11D48),
        backgroundColor: const Color(0xFFFFF1F2),
        borderColor: const Color(0xFFFECDD3),
        label: isDeparture ? 'DEPARTURE' : (isFlight ? 'FLIGHT' : 'TRANSPORT'),
      );
    } else if (cat.contains('lodging') ||
        cat.contains('hotel') ||
        sub.contains('hotel') ||
        sub.contains('check-in')) {
      return const EventCategoryStyle(
        icon: Icons.hotel_rounded,
        primaryColor: Color(0xFF7C3AED),
        backgroundColor: Color(0xFFFAF5FF),
        borderColor: Color(0xFFE9D5FF),
        label: 'LODGING',
      );
    } else if (cat.contains('meal') ||
        cat.contains('food') ||
        cat.contains('dine') ||
        cat.contains('restaurant')) {
      return const EventCategoryStyle(
        icon: Icons.restaurant_rounded,
        primaryColor: Color(0xFFD97706),
        backgroundColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
        label: 'MEAL',
      );
    } else if (cat.contains('info') ||
        cat.contains('note') ||
        title.contains('doc') ||
        title.contains('pass')) {
      return const EventCategoryStyle(
        icon: Icons.info_outline_rounded,
        primaryColor: Color(0xFF2563EB),
        backgroundColor: Color(0xFFEFF6FF),
        borderColor: Color(0xFFBFDBFE),
        label: 'INFO',
      );
    } else {
      return const EventCategoryStyle(
        icon: Icons.directions_walk_rounded,
        primaryColor: Color(0xFF059669),
        backgroundColor: Color(0xFFF0FDF4),
        borderColor: Color(0xFFA7F3D0),
        label: 'ACTIVITY',
      );
    }
  }
}

/// Dedicated Day Schedule Screen displaying top 2-column index cards,
/// detailed scrollable event cards (strictly without cover images),
/// auto-scroll with 1-second glowing border highlight on index tap,
/// and a bottom-center upward scroll-to-top button.
class DayScheduleScreen extends StatefulWidget {
  final MobileDiContainer di;
  final TripPackage trip;
  final ItineraryDay day;

  const DayScheduleScreen({
    super.key,
    required this.di,
    required this.trip,
    required this.day,
  });

  @override
  State<DayScheduleScreen> createState() => _DayScheduleScreenState();
}

class _DayScheduleScreenState extends State<DayScheduleScreen> {
  late final ScrollController _scrollController;
  bool _showScrollToTop = false;
  int? _highlightedEventIndex;
  Timer? _glowTimer;
  final Map<int, GlobalKey> _eventKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    for (int i = 0; i < widget.day.events.length; i++) {
      _eventKeys[i] = GlobalKey();
    }
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 80;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _glowTimer?.cancel();
    super.dispose();
  }

  /// Tapping an index card smoothly auto-scrolls to the target event card
  /// and applies a glowing border highlight for 1 second.
  void _scrollToEvent(int index) {
    final key = _eventKeys[index];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.05,
      );
    }

    setState(() {
      _highlightedEventIndex = index;
    });

    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _highlightedEventIndex = null;
        });
      }
    });
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  String _formatDayDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      DateTime dt;
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            dt = DateTime.parse(dateStr);
          } else if (parts[2].length == 4) {
            dt = DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          } else {
            return dateStr;
          }
        } else {
          dt = DateTime.parse(dateStr);
        }
      } else {
        dt = DateTime.parse(dateStr);
      }

      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday, $month ${dt.day}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getCompactTime(ItineraryEvent ev) {
    if (ev.subDetail != null && ev.subDetail!.isNotEmpty) {
      return ev.subDetail!;
    }
    if (ev.startIso8601.isNotEmpty) {
      try {
        final dt = DateTime.parse(ev.startIso8601);
        final hour =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return '$hour:$minute $period';
      } catch (_) {
        if (ev.startIso8601.contains(':')) {
          return ev.startIso8601;
        }
      }
    }
    if (ev.subCategory.isNotEmpty) {
      return ev.subCategory;
    }
    return '';
  }

  String _getTimeRange(ItineraryEvent ev) {
    if (ev.subDetail != null && ev.subDetail!.isNotEmpty) {
      return ev.subDetail!;
    }
    if (ev.startIso8601.isNotEmpty) {
      try {
        final dt = DateTime.parse(ev.startIso8601);
        final hour =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        final minute = dt.minute.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';

        if (ev.endIso8601.isNotEmpty) {
          try {
            final endDt = DateTime.parse(ev.endIso8601);
            final endHour = endDt.hour == 0
                ? 12
                : (endDt.hour > 12 ? endDt.hour - 12 : endDt.hour);
            final endMin = endDt.minute.toString().padLeft(2, '0');
            final endPeriod = endDt.hour >= 12 ? 'PM' : 'AM';
            return '$hour:$minute $period - $endHour:$endMin $endPeriod';
          } catch (_) {}
        }
        return '$hour:$minute $period';
      } catch (_) {
        if (ev.startIso8601.contains(':')) {
          return ev.startIso8601;
        }
      }
    }
    return '';
  }

  String? _getEventLocation(ItineraryEvent ev) {
    if (ev.activity != null && ev.activity!.meetingPointAddress.isNotEmpty) {
      return ev.activity!.meetingPointAddress;
    }
    if (ev.lodging != null && ev.lodging!.address.isNotEmpty) {
      return ev.lodging!.address;
    }
    if (ev.meal != null && ev.meal!.address.isNotEmpty) {
      return ev.meal!.address;
    }
    if (ev.transport != null && ev.transport!.pickupLocation.isNotEmpty) {
      return ev.transport!.pickupLocation;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final day = widget.day;
    final dayTitle = day.title.toLowerCase().startsWith('day ${day.dayNumber}:')
        ? day.title
        : 'Day ${day.dayNumber}: ${day.title}';
    final formattedDate = _formatDayDate(day.dateIso8601);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              // Dedicated Top App Bar
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.chevron_left_rounded,
                          color: Color(0xFF0F172A),
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayTitle,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  children: [
                    // Day Description Card (if any)
                    if (day.description.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A)
                                  .withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          day.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF334155),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    // Top Indices Section (2-Column Tabular Grid, Odd Centered)
                    _buildIndexSection(context),

                    const SizedBox(height: 18),

                    // Schedule & Detailed Event Cards Section
                    _buildEventsSection(context),
                  ],
                ),
              ),
            ],
          ),

          // Floating Upward Arrow Button at Bottom Center
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedScale(
                scale: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showScrollToTop ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Material(
                    color: const Color(0xFF0F172A),
                    shape: const CircleBorder(),
                    elevation: 6,
                    shadowColor: Colors.black38,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _scrollToTop,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the 2-column tabular index section matching Image 4 & 5.
  /// If there are an odd number of cards, the last card appears centrally.
  Widget _buildIndexSection(BuildContext context) {
    final events = widget.day.events;
    if (events.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    // 16 left + 16 right padding = 32. 10 spacing between 2 columns.
    final cardWidth = (screenWidth - 32 - 10) / 2;

    final rows = <Widget>[];
    for (int i = 0; i < events.length; i += 2) {
      if (i + 1 < events.length) {
        // Two index cards in this row
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(child: _buildIndexCard(events[i], i)),
                const SizedBox(width: 10),
                Expanded(child: _buildIndexCard(events[i + 1], i + 1)),
              ],
            ),
          ),
        );
      } else {
        // Odd number of cards -> last card appears centrally
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _buildIndexCard(events[i], i),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DAY OVERVIEW',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Color(0xFF64748B),
              ),
            ),
            Text(
              '${events.length} event${events.length > 1 ? "s" : ""}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }

  /// Compact static index card strictly without cover images.
  /// Matches Image 5 shape: rounded rectangle, pastel category tint, category tag,
  /// timing, and concise event topic.
  Widget _buildIndexCard(ItineraryEvent ev, int index) {
    final style = EventCategoryStyle.resolve(ev);
    final timeStr = _getCompactTime(ev);

    return Material(
      color: style.backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _scrollToEvent(index),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: style.borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: style.primaryColor.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: Category tag on left, Time on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: style.borderColor.withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(style.icon, size: 10.5, color: style.primaryColor),
                        const SizedBox(width: 3.5),
                        Text(
                          style.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: style.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (timeStr.isNotEmpty)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Topic of the event described
              Text(
                ev.title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the Schedule & Events section with detailed event cards.
  Widget _buildEventsSection(BuildContext context) {
    final events = widget.day.events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Events & Schedule',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'No schedule events planned for this day yet.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          )
        else
          ...List.generate(events.length, (index) {
            return _buildEventCard(context, events[index], index);
          }),
      ],
    );
  }

  /// Builds an individual detailed event card.
  /// Strictly without cover images!
  /// Supports glowing 1-second border highlight when tapped from index.
  Widget _buildEventCard(
      BuildContext context, ItineraryEvent ev, int index) {
    final hasPhotos = ev.photos.isNotEmpty;
    final hasDocs = ev.documents.isNotEmpty;
    final hasDesc = ev.description.isNotEmpty ||
        (ev.note?.markdownBody.isNotEmpty ?? false);
    final desc = ev.description.isNotEmpty
        ? ev.description
        : (ev.note?.markdownBody ?? '');

    final style = EventCategoryStyle.resolve(ev);
    final isHighlighted = _highlightedEventIndex == index;
    final timeRange = _getTimeRange(ev);
    final location = _getEventLocation(ev);

    final categoryLabel = ev.subCategory.isNotEmpty
        ? '${ev.category.isNotEmpty ? ev.category : "Event"} · ${ev.subCategory}'
        : (ev.category.isNotEmpty ? ev.category : style.label);

    return AnimatedContainer(
      key: _eventKeys[index],
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFF2563EB)
              : const Color(0xFFE2E8F0),
          width: isHighlighted ? 2.5 : 1.0,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.40),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Category Badge, Subcategory Pill, Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: style.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: style.borderColor, width: 1),
                ),
                child: Icon(style.icon, color: style.primaryColor, size: 16),
              ),
              const SizedBox(width: 8),
              if (categoryLabel.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    categoryLabel.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              if (timeRange.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        timeRange,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Event Title (strictly bold, no cover image)
          Text(
            ev.title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.2,
              color: Color(0xFF0F172A),
            ),
          ),

          // Formatted Description Widget
          if (hasDesc) ...[
            const SizedBox(height: 10),
            _buildDescriptionWidget(desc),
          ],

          // Location Cards (Location, Coordinates, and Map link)
          _buildLocationCards(context, ev),

          // PHOTOS Gallery
          if (hasPhotos) ...[
            const SizedBox(height: 14),
            const Text(
              'PHOTOS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ev.photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, pIdx) {
                  final photo = ev.photos[pIdx];
                  return GestureDetector(
                    onTap: () => _viewPhoto(context, photo),
                    child: Container(
                      width: 100,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        color: const Color(0xFFF1F5F9),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildPhotoWidget(photo),
                    ),
                  );
                },
              ),
            ),
          ],

          // DOCUMENTS & PASSES
          if (hasDocs) ...[
            const SizedBox(height: 14),
            const Text(
              'DOCUMENTS & PASSES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: ev.documents
                  .map((doc) => _buildEventDocumentPill(context, doc))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationCards(BuildContext context, ItineraryEvent ev) {
    final cards = ev.locationCards;
    if (cards.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards.map((loc) {
          final locName = (loc['locationName'] as String?)?.trim() ?? '';
          final rawUrl = (loc['rawUrl'] as String?)?.trim() ?? '';
          final lat = (loc['latitude'] as num?)?.toDouble();
          final lng = (loc['longitude'] as num?)?.toDouble();

          String coordsText = '';
          if (lat != null && lng != null) {
            final latDir = lat >= 0 ? 'N' : 'S';
            final lngDir = lng >= 0 ? 'E' : 'W';
            coordsText =
                '${lat.abs().toStringAsFixed(4)}° $latDir, ${lng.abs().toStringAsFixed(4)}° $lngDir';
          } else if (rawUrl.isNotEmpty && !rawUrl.startsWith('http')) {
            coordsText = rawUrl;
          }

          final displayName = locName.isNotEmpty
              ? locName
              : (coordsText.isNotEmpty ? coordsText : 'Location Map');

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: (rawUrl.isNotEmpty || (lat != null && lng != null))
                    ? () => _openMapLocation(
                        context, rawUrl, lat, lng, displayName)
                    : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
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
                              displayName,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (coordsText.isNotEmpty &&
                                coordsText != displayName) ...[
                              const SizedBox(height: 2),
                              Text(
                                coordsText,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (rawUrl.isNotEmpty || (lat != null && lng != null))
                        const Icon(
                          Icons.open_in_new_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openMapLocation(BuildContext context, String rawUrl,
      double? lat, double? lng, String title) async {
    try {
      String targetUrl = rawUrl;
      if (targetUrl.isEmpty && lat != null && lng != null) {
        targetUrl =
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      }
      if (targetUrl.isNotEmpty) {
        const platform =
            MethodChannel('com.tripytravy.client_mobile/file_intent');
        await platform.invokeMethod('openUrl', {'url': targetUrl});
      }
    } catch (_) {}
  }

  Widget _buildDescriptionWidget(String text) {
    const baseStyle =
        TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4);
    if (!text.contains('**') &&
        !text.contains('*') &&
        !text.contains('<u>') &&
        !text.contains('==') &&
        !text.contains('[')) {
      return Text(text, style: baseStyle);
    }
    return Text.rich(
      TextSpan(children: _parseDescriptionSpans(text, baseStyle)),
    );
  }

  static List<InlineSpan> _parseDescriptionSpans(
      String text, TextStyle baseStyle) {
    if (text.isEmpty) return [TextSpan(text: '', style: baseStyle)];
    final tokenRegex = RegExp(
      r'(\*\*((?:[^\*]|\*(?!\*))+?)\*\*|'
      r'(?<!\*)\*([^\*\n]+?)\*(?!\*)|'
      r'<u>([\s\S]*?)</u>|'
      r'==((?:[^=]|=(?!=))+?)==|'
      r'\[([^\]\n]+)\]\(([^)\n]*)\))',
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    int last = 0;
    for (final m in tokenRegex.allMatches(text)) {
      if (m.start > last) {
        spans.add(
            TextSpan(text: text.substring(last, m.start), style: baseStyle));
      }
      final matched = m.group(0)!;
      if (matched.startsWith('**') && matched.endsWith('**')) {
        final inner = m.group(2) ?? matched.substring(2, matched.length - 2);
        spans.add(TextSpan(
            text: inner,
            style: baseStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A))));
      } else if (matched.startsWith('*') && matched.endsWith('*')) {
        final inner = m.group(3) ?? matched.substring(1, matched.length - 1);
        spans.add(TextSpan(
            text: inner,
            style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      } else if (matched.toLowerCase().startsWith('<u>')) {
        final inner = m.group(4) ?? matched.substring(3, matched.length - 4);
        spans.add(TextSpan(
            text: inner,
            style: baseStyle.copyWith(decoration: TextDecoration.underline)));
      } else if (matched.startsWith('==') && matched.endsWith('==')) {
        var inner = m.group(5) ?? matched.substring(2, matched.length - 2);
        Color hlBg = const Color(0xFFFEF08A);
        Color hlText = const Color(0xFF0F172A);
        if (inner.startsWith('red:')) {
          inner = inner.substring(4);
          hlBg = const Color(0xFFFEE2E2);
          hlText = const Color(0xFF991B1B);
        } else if (inner.startsWith('navy:')) {
          inner = inner.substring(5);
          hlBg = const Color(0xFFE0E7FF);
          hlText = const Color(0xFF1E1B4B);
        }
        spans.add(TextSpan(
            text: inner,
            style: baseStyle.copyWith(
                backgroundColor: hlBg,
                color: hlText,
                fontWeight: FontWeight.w600)));
      } else if (matched.startsWith('[')) {
        final label = m.group(6) ?? '';
        spans.add(TextSpan(
            text: label,
            style: baseStyle.copyWith(
                color: const Color(0xFF2563EB),
                decoration: TextDecoration.underline)));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }
    return spans;
  }

  Widget _buildEventDocumentPill(BuildContext context, TripDocumentRecord doc) {
    final subtitle = doc.fileSize.isNotEmpty
        ? '${doc.docType} · ${doc.fileSize}'
        : doc.docType;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openDocument(context, doc),
          child: Row(
            children: [
              Container(
                width: 48,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(11)),
                ),
                child: const Center(
                  child: Icon(Icons.attach_file_rounded,
                      size: 20, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoWidget(String photo) {
    if (photo.startsWith('data:image/') ||
        (!photo.startsWith('http') &&
            !photo.startsWith('assets') &&
            photo.length > 100)) {
      try {
        final comma = photo.indexOf(',');
        final base64Str = comma != -1 ? photo.substring(comma + 1) : photo;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoFallback(),
        );
      } catch (_) {
        return _photoFallback();
      }
    } else if (photo.startsWith('http://') || photo.startsWith('https://')) {
      return Image.network(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoFallback(),
      );
    } else if (photo.startsWith('assets/')) {
      return Image.asset(
        photo,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoFallback(),
      );
    } else {
      final file = File(photo);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoFallback(),
        );
      }
      return _photoFallback();
    }
  }

  Widget _photoFallback() => const Center(
        child: Icon(Icons.broken_image_rounded,
            color: Color(0xFF94A3B8), size: 24),
      );

  void _viewPhoto(BuildContext context, String photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4.0,
                child: _buildPhotoWidget(photo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDocument(
      BuildContext context, TripDocumentRecord doc) async {
    try {
      File? fileToOpen;
      if (doc.base64Data != null && doc.base64Data!.isNotEmpty) {
        final comma = doc.base64Data!.indexOf(',');
        final cleanBase64 = comma != -1
            ? doc.base64Data!.substring(comma + 1)
            : doc.base64Data!;
        final bytes =
            base64Decode(cleanBase64.replaceAll(RegExp(r'\s+'), ''));
        final tempDir = await getTemporaryDirectory();
        final ext = (doc.fileName.contains('.')
                ? ''
                : (doc.docType.toLowerCase().contains('pdf') ? '.pdf' : ''))
            .trim();
        final rawName = doc.fileName.isNotEmpty ? doc.fileName : doc.title;
        final safeName = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final targetFileName = '$safeName$ext';
        final file = File('${tempDir.path}/$targetFileName');
        await file.writeAsBytes(bytes, flush: true);
        fileToOpen = file;
      } else if (doc.filePath.isNotEmpty) {
        final f = File(doc.filePath);
        if (await f.exists()) {
          fileToOpen = f;
        }
      }

      if (fileToOpen != null && await fileToOpen.exists()) {
        String mimeType = 'application/octet-stream';
        final pathLower = fileToOpen.path.toLowerCase();
        if (pathLower.endsWith('.pdf')) {
          mimeType = 'application/pdf';
        } else if (pathLower.endsWith('.png')) {
          mimeType = 'image/png';
        } else if (pathLower.endsWith('.jpg') || pathLower.endsWith('.jpeg')) {
          mimeType = 'image/jpeg';
        } else if (pathLower.endsWith('.txt')) {
          mimeType = 'text/plain';
        } else if (pathLower.endsWith('.docx')) {
          mimeType =
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (pathLower.endsWith('.doc')) {
          mimeType = 'application/msword';
        }

        const platform =
            MethodChannel('com.tripytravy.client_mobile/file_intent');
        await platform.invokeMethod('openFile', {
          'path': fileToOpen.path,
          'mimeType': mimeType,
        });
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document file data is not available in itinerary.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open document: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
