import 'dart:io';
import 'package:flutter/material.dart';
import '../data/itinerary_database.dart';
import '../data/itinerary_file_manager.dart';
import 'exported_itineraries_screen.dart';
import 'trip_editor_dialog.dart';
import 'trip_detail_screen.dart';
import 'widgets/smooth_scroll.dart';

class DashboardScreen extends StatefulWidget {
  final List<DestinationItem>? initialDestinations;

  const DashboardScreen({super.key, this.initialDestinations});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  late final ScrollController _scrollController;
  List<DestinationItem> _destinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    if (widget.initialDestinations != null) {
      _destinations = List.from(widget.initialDestinations!);
      _isLoading = false;
      ItineraryFileManager.ensureDefaultFolders(_destinations.map((i) => i.title).toList());
    } else {
      _loadItineraries();
    }
  }

  Future<void> _loadItineraries() async {
    final items = await ItineraryDatabase.instance.getAllItineraries();
    await ItineraryFileManager.ensureDefaultFolders(items.map((i) => i.title).toList());
    if (mounted) {
      setState(() {
        _destinations = items;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmationDialog(DestinationItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
            SizedBox(width: 8),
            Text(
              'Delete Itinerary',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete it?',
              style: TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'This will remove "${item.title}" from your dashboard.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ItineraryDatabase.instance.deleteItinerary(item.id);
              if (mounted) {
                setState(() {
                  _destinations.removeWhere((d) => d.id == item.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFDC2626),
                    content: Text('Itinerary "${item.title}" deleted.'),
                  ),
                );
              }
            },
            child: const Text('Okay', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTripEditorDialog({DestinationItem? itemToEdit}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TripEditorDialog(
        itemToEdit: itemToEdit,
        onSave: (savedItem) async {
          if (itemToEdit == null) {
            // Create new trip
            final created = await ItineraryDatabase.instance.insertItinerary(
              title: savedItem.title,
              subtitle: savedItem.subtitle,
              duration: savedItem.duration,
              dateRange: savedItem.dateRange,
              imagePath: savedItem.imagePath,
              startDate: savedItem.startDate,
              endDate: savedItem.endDate,
            );
            await ItineraryFileManager.ensureItineraryFolder(created.title);
            if (mounted) {
              setState(() {
                _destinations.add(created);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0066FF),
                  content: Text('Trip "${created.title}" created successfully!'),
                ),
              );
            }
          } else {
            // Edit existing trip
            await ItineraryDatabase.instance.updateItinerary(savedItem);
            await ItineraryFileManager.ensureItineraryFolder(savedItem.title);
            if (mounted) {
              setState(() {
                final idx = _destinations.indexWhere((d) => d.id == savedItem.id);
                if (idx != -1) {
                  _destinations[idx] = savedItem;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF0066FF),
                  content: Text('Trip "${savedItem.title}" updated successfully!'),
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.settings, color: Color(0xFF0066FF)),
            SizedBox(width: 10),
            Text('TripyTravy Settings', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TripyTravy Desktop v0.1.0', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('100% Free, Privacy-First, Decentralized Travel Planning.'),
            SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.security, size: 18, color: Colors.green),
                SizedBox(width: 8),
                Text('AES-256-GCM + TTRV v1 Container Enabled'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.wifi_off_rounded, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text('100% Offline Autonomy Active'),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDashboardDrawer(),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollController,
          interactive: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const ClampingScrollPhysics(),
            child: SmoothScroll(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(child: _buildTopHeader()),
                  const SizedBox(height: 28),
                  RepaintBoundary(child: _buildCardsSection()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.travel_explore_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TripyTravy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Agent Workspace',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: Color(0xFF0066FF)),
                  title: const Text(
                    'All Itineraries',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0066FF),
                    ),
                  ),
                  tileColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                ListTile(
                  key: const Key('drawer_exported_itineraries_option'),
                  leading: const Icon(Icons.inventory_2_outlined, color: Color(0xFF475569)),
                  title: const Text(
                    'Exported itineraries',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExportedItinerariesScreen(
                          initialItineraries: _destinations,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                ListTile(
                  leading: const Icon(Icons.folder_open_outlined, color: Color(0xFF475569)),
                  title: const Text(
                    'Open Root Folder',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ItineraryFileManager.openBaseFolderInExplorer();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Decentralized .tt Engine Active',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: Row(
        children: [
          // Hamburger Icon at top left corner
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('dashboard_hamburger_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFF1E293B),
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14), // Shift the logo a little bit

          // Left: TripyTravy Official White-Themed Brand Logo
          Image.asset(
            'assets/images/TripyTravyWhiteTheme.png',
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.travel_explore_rounded,
              color: Color(0xFF0066FF),
              size: 38,
            ),
          ),
          const SizedBox(width: 28),

          // Center-Left: Search Bar
          Expanded(
            child: Container(
              height: 44,
              constraints: const BoxConstraints(maxWidth: 580),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FA),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Color(0xFF7A8B9E),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                      decoration: const InputDecoration(
                        hintText: 'search Itinerary Name.',
                        hintStyle: TextStyle(
                          color: Color(0xFF7A8B9E),
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Right: + Add More Trip button
          ElevatedButton.icon(
            onPressed: () => _showTripEditorDialog(),
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Add More Trip',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 0,
            ),
          ),

          const SizedBox(width: 16),

          // Rightmost: Settings Icon
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _showSettingsDialog,
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF5A6B82),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardsSection() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        height: 250,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(color: Color(0xFF0066FF), strokeWidth: 2.5),
        ),
      );
    }

    if (_destinations.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        height: 220,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.luggage_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No itineraries yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Click "+ Add More Trip" above to plan your next adventure.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _destinations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, index) {
                final item = _destinations[index];
                return ItineraryCard(
                  item: item,
                  onTap: () => _openTripDetail(item),
                  onDelete: () => _showDeleteConfirmationDialog(item),
                  onEdit: () => _showTripEditorDialog(itemToEdit: item),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openTripDetail(DestinationItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TripDetailScreen(item: item),
      ),
    ).then((_) => _loadItineraries());
  }
}

class ItineraryCard extends StatefulWidget {
  final DestinationItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ItineraryCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<ItineraryCard> createState() => _ItineraryCardState();
}

class _ItineraryCardState extends State<ItineraryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const animationDuration = Duration(milliseconds: 280);
    const animationCurve = Curves.easeOutCubic;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: animationDuration,
          curve: animationCurve,
          width: _isHovered ? 350 : 330,
          height: 220,
          transform: Matrix4.translationValues(0, _isHovered ? -6 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF0066FF).withValues(alpha: 0.28),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: -2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Background Image with subtle zoom on hover
                AnimatedScale(
                  scale: _isHovered ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 350),
                  curve: animationCurve,
                  child: _buildCardBanner(widget.item.imagePath, widget.item.title),
                ),

                // 2. Smooth Gradient overlay for contrast
                AnimatedContainer(
                  duration: animationDuration,
                  curve: animationCurve,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _isHovered
                          ? [
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.25),
                              Colors.black.withValues(alpha: 0.88),
                            ]
                          : [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.72),
                            ],
                    ),
                  ),
                ),

                // 3. Top-Right Three-Dot Options Menu
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        popupMenuTheme: PopupMenuThemeData(
                          color: Colors.white,
                          elevation: 10,
                          shadowColor: Colors.black.withValues(alpha: 0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      child: PopupMenuButton<String>(
                        tooltip: 'Card Options',
                        padding: EdgeInsets.zero,
                        splashRadius: 18,
                        icon: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            widget.onEdit();
                          } else if (value == 'delete') {
                            widget.onDelete();
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F172A)),
                                SizedBox(width: 10),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(height: 1),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            height: 38,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 10),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 5. Bottom Content
                Positioned(
                  left: 14,
                  right: _isHovered ? 56 : 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Destination Title
                      AnimatedDefaultTextStyle(
                        duration: animationDuration,
                        curve: animationCurve,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: _isHovered ? 22 : 25,
                          letterSpacing: -0.5,
                          shadows: const [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(widget.item.title),
                      ),

                      // Smooth Details Container
                      ClipRect(
                        child: AnimatedSize(
                          duration: animationDuration,
                          curve: animationCurve,
                          alignment: Alignment.topCenter,
                          child: AnimatedOpacity(
                            duration: animationDuration,
                            curve: animationCurve,
                            opacity: _isHovered ? 1.0 : 0.0,
                            child: _isHovered
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 3),
                                      Text(
                                        widget.item.subtitle,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.92),
                                          fontSize: 11,
                                          height: 1.2,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.item.duration,
                                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 1,
                                            height: 10,
                                            color: Colors.white54,
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 12),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              widget.item.dateRange,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Blue Action Arrow Button (Smooth scale and fade on hover)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: AnimatedScale(
                    scale: _isHovered ? 1.0 : 0.6,
                    duration: animationDuration,
                    curve: animationCurve,
                    child: AnimatedOpacity(
                      opacity: _isHovered ? 1.0 : 0.0,
                      duration: animationDuration,
                      curve: animationCurve,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: widget.onTap,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0066FF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0066FF).withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBanner(String path, String fallbackTitle) {
    if (path.isEmpty) {
      return _buildFallbackBanner(fallbackTitle);
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(fallbackTitle),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(fallbackTitle),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildFallbackBanner(fallbackTitle),
      );
    }
    return _buildFallbackBanner(fallbackTitle);
  }

  Widget _buildFallbackBanner(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white60,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
