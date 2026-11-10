import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A wrapper widget that provides buttery-smooth, interpolated scrolling
/// for desktop mouse wheels without fighting native physics, lagging on trackpads,
/// velocity spikes, or micro-stutter on continuous scrolls.
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
    this.curve = Curves.easeOutQuad,
  });

  @override
  State<SmoothScroll> createState() => _SmoothScrollState();
}

class _SmoothScrollState extends State<SmoothScroll>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _targetOffset = 0.0;
  Duration _lastElapsed = Duration.zero;
  bool _isFirstTick = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !widget.controller.hasClients) {
      _ticker.stop();
      return;
    }

    // If user is actively dragging the scrollbar thumb with a pointer, yield immediately
    if (widget.controller.position.activity is DragScrollActivity) {
      _ticker.stop();
      _targetOffset = widget.controller.offset;
      return;
    }

    double dt;
    if (_isFirstTick) {
      _lastElapsed = elapsed;
      _isFirstTick = false;
      dt = 0.016; // 16ms nominal step so motion responds on frame 1 without delay
    } else {
      dt = (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
      _lastElapsed = elapsed;
    }

    if (dt <= 0.0) return;
    // Clamp dt to [1ms, 50ms] to avoid huge jumps on sudden frame delays
    final double clampedDt = dt.clamp(0.001, 0.05);

    final position = widget.controller.position;
    final double minOffset = position.minScrollExtent;
    final double maxOffset = position.maxScrollExtent;
    final double currentOffset = widget.controller.offset;

    // Detect if external jump occurred (e.g. user clicked or dragged scrollbar)
    if ((currentOffset - _targetOffset).abs() > 300.0) {
      _targetOffset = currentOffset;
      _ticker.stop();
      return;
    }

    _targetOffset = _targetOffset.clamp(minOffset, maxOffset);
    final double diff = _targetOffset - currentOffset;

    // When within subpixel threshold, snap to target and finish
    if (diff.abs() < 0.25) {
      widget.controller.jumpTo(_targetOffset);
      _ticker.stop();
      return;
    }

    // Continuous time-invariant critically damped smoothing:
    // Derives decay rate lambda so ~98% of target distance is covered over animationDuration
    final double durationSeconds =
        (widget.animationDuration.inMilliseconds / 1000.0).clamp(0.08, 0.5);
    final double lambda = 3.91 / durationSeconds;
    final double blend = 1.0 - math.exp(-lambda * clampedDt);
    final double nextOffset =
        (currentOffset + diff * blend).clamp(minOffset, maxOffset);

    if ((nextOffset - currentOffset).abs() > 0.001) {
      widget.controller.jumpTo(nextOffset);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Laptop trackpads (Windows Precision Touchpad / macOS trackpad) already send
      // smooth, subpixel, 120Hz/60Hz hardware-accelerated inertia events natively.
      // Intercepting trackpad events causes latency and stutter.
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

    // If ticker was idle or position diverged externally, sync target to current
    if (!_ticker.isActive || (currentOffset - _targetOffset).abs() > 300.0) {
      _targetOffset = currentOffset;
      _lastElapsed = Duration.zero;
      _isFirstTick = true;
    }

    // Accumulate target offset seamlessly without any velocity spikes or resets
    _targetOffset = (_targetOffset + delta).clamp(minOffset, maxOffset);

    if (!_ticker.isActive && (_targetOffset - currentOffset).abs() > 0.01) {
      _ticker.start();
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
