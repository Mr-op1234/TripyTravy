import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that provides buttery-smooth, interpolated scrolling
/// for desktop mouse wheels, replacing the abrupt step-jumps of default
/// Flutter desktop scrolling.
class SmoothScroll extends StatefulWidget {
  final ScrollController controller;
  final Widget child;
  final double scrollSpeed;
  final Duration animationDuration;
  final Curve curve;

  const SmoothScroll({
    super.key,
    required this.controller,
    required this.child,
    this.scrollSpeed = 1.0,
    this.animationDuration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll> {
  double _targetOffset = 0.0;
  bool _isAnimating = false;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        _handlePointerScroll,
      );
    }
  }

  void _handlePointerScroll(PointerEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!widget.controller.hasClients) return;

    final double delta = event.scrollDelta.dy * widget.scrollSpeed;
    if (delta == 0.0) return;

    final position = widget.controller.position;
    final double minOffset = position.minScrollExtent;
    final double maxOffset = position.maxScrollExtent;
    final double currentOffset = widget.controller.offset;

    // Check if the current position diverged from the previous target
    // (e.g. user dragged scrollbar thumb, keyboard scrolled, or jumped)
    final bool diverged =
        (currentOffset - _targetOffset).abs() > (delta.abs() * 2.5 + 40.0);

    final bool isContinuingSameDirection = _isAnimating &&
        !diverged &&
        ((delta > 0 && _targetOffset >= currentOffset) ||
            (delta < 0 && _targetOffset <= currentOffset));

    if (isContinuingSameDirection) {
      _targetOffset += delta;
    } else {
      _targetOffset = currentOffset + delta;
    }

    _targetOffset = _targetOffset.clamp(minOffset, maxOffset);

    if (_targetOffset != currentOffset) {
      _isAnimating = true;
      widget.controller
          .animateTo(
            _targetOffset,
            duration: widget.animationDuration,
            curve: widget.curve,
          )
          .catchError((_) {})
          .then((_) {
            if (mounted && widget.controller.hasClients) {
              if ((widget.controller.offset - _targetOffset).abs() < 2.0) {
                _isAnimating = false;
              }
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _onPointerSignal,
      child: widget.child,
    );
  }
}
