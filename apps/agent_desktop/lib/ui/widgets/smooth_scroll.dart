import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A wrapper widget that provides buttery-smooth, interpolated scrolling
/// for desktop mouse wheels without fighting native physics, lagging on trackpads,
/// or rubberbanding on continuous scrolls.
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
    this.animationDuration = const Duration(milliseconds: 160),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  double _startOffset = 0.0;
  double _targetOffset = 0.0;
  double _currentAnimTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..addListener(_onAnimTick);
  }

  @override
  void didUpdateWidget(SmoothScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationDuration != widget.animationDuration) {
      _animController.duration = widget.animationDuration;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onAnimTick() {
    if (!mounted || !widget.controller.hasClients) return;

    // If user is actively dragging the scrollbar thumb with a pointer, yield immediately
    if (widget.controller.position.activity is DragScrollActivity) {
      _animController.stop();
      return;
    }

    final double curvedProgress = widget.curve.transform(_animController.value);
    final double newOffset =
        _startOffset + (_targetOffset - _startOffset) * curvedProgress;
    final double clamped = newOffset.clamp(
      widget.controller.position.minScrollExtent,
      widget.controller.position.maxScrollExtent,
    );

    if ((clamped - widget.controller.offset).abs() > 0.001) {
      widget.controller.jumpTo(clamped);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Laptop trackpads (Windows Precision Touchpad / macOS trackpad) already send
      // smooth, subpixel, 120Hz/60Hz hardware-accelerated inertia events natively.
      // Intercepting trackpad events causes severe latency and lag.
      if (event.kind == PointerDeviceKind.trackpad) {
        return;
      }

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

    // Detect if external jump occurred (e.g. user dragged scrollbar thumb)
    if ((currentOffset - _currentAnimTarget).abs() > 250.0) {
      _targetOffset = currentOffset;
    }

    final bool isContinuingSameDirection = _animController.isAnimating &&
        ((delta > 0 && _targetOffset >= currentOffset) ||
            (delta < 0 && _targetOffset <= currentOffset));

    if (isContinuingSameDirection) {
      _targetOffset += delta;
    } else {
      _targetOffset = currentOffset + delta;
    }

    _targetOffset = _targetOffset.clamp(minOffset, maxOffset);
    _currentAnimTarget = _targetOffset;

    if ((_targetOffset - currentOffset).abs() > 0.1) {
      _startOffset = currentOffset;
      _animController.duration = widget.animationDuration;
      _animController.forward(from: 0.0);
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
