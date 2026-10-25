import 'package:flutter/material.dart';
import 'rounded_curved_arrow_painter.dart';

/// Minimalistic, subtle empty state widget shown when no trips are available.
/// Displays "No trips, Import one" and a rounded curved arrow pointing down
/// directly to the '+' action button.
class EmptyTripsView extends StatelessWidget {
  final VoidCallback onImportTap;

  const EmptyTripsView({
    super.key,
    required this.onImportTap,
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
                    const Spacer(flex: 3),
                    // Subtle themed minimalistic text
                    GestureDetector(
                      onTap: onImportTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'No trips, Import one',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF0D2356).withValues(alpha: 0.40),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rounded curved arrow leading directly down to the center '+' button
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 180,
                        child: CustomPaint(
                          painter: RoundedCurvedArrowPainter(
                            color: const Color(0xFF0D2356).withValues(alpha: 0.35),
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                    ),
                    // Spacing so the arrow tip lands right above the bottom '+' button
                    const SizedBox(height: 72),
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
