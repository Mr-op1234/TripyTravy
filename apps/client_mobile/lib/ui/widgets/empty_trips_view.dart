import 'package:flutter/material.dart';
import 'rounded_curved_arrow_painter.dart';

/// Minimalistic, subtle empty state widget shown when no trips are available.
/// Displays non-interactive background text "No trips? Import one!!" and a rounded curved arrow
/// pointing down directly to the '+' action button with breathing room.
class EmptyTripsView extends StatelessWidget {
  final VoidCallback? onImportTap;

  const EmptyTripsView({
    super.key,
    this.onImportTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final totalWidth = constraints.maxWidth;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: totalHeight,
              minWidth: totalWidth,
            ),
            child: IntrinsicHeight(
              child: SizedBox(
                width: totalWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Shifted upwards with smaller top spacer
                    const Spacer(flex: 1),
                    // Non-clickable background text
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'No trips? Import one!!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D2356).withValues(alpha: 0.50),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Larger rounded curved arrow leading down to the center '+' button
                    Center(
                      child: SizedBox(
                        width: 170,
                        height: 230,
                        child: CustomPaint(
                          painter: RoundedCurvedArrowPainter(
                            color: const Color(0xFF0D2356).withValues(alpha: 0.40),
                            strokeWidth: 2.6,
                          ),
                        ),
                      ),
                    ),
                    // Distance keeping arrow from touching the '+' icon below
                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
