import 'package:flutter/material.dart';

/// Displays the photos belonging to one event, starting with the tapped photo.
class PhotoGalleryDialog extends StatefulWidget {
  final List<String> photos;
  final int initialIndex;
  final Widget Function(String photo) imageBuilder;

  const PhotoGalleryDialog(
      {super.key,
      required this.photos,
      required this.initialIndex,
      required this.imageBuilder});

  @override
  State<PhotoGalleryDialog> createState() => _PhotoGalleryDialogState();
}

class _PhotoGalleryDialogState extends State<PhotoGalleryDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (widget.photos.length > 1)
              Text('${_index + 1} / ${widget.photos.length}',
                  style: const TextStyle(color: Colors.white)),
            const Spacer(),
            IconButton(
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.65,
            child: PageView.builder(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => _ZoomablePhoto(
                key: ValueKey(index),
                onSwipe: (direction) {
                  final next = _index + direction;
                  if (next >= 0 && next < widget.photos.length) {
                    _controller.animateToPage(next,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                  }
                },
                child: widget.imageBuilder(widget.photos[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoomablePhoto extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onSwipe;
  const _ZoomablePhoto({super.key, required this.child, required this.onSwipe});
  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto> {
  final TransformationController _controller = TransformationController();
  Offset _start = Offset.zero;
  Offset _end = Offset.zero;
  bool _startedZoomed = false;
  int _pointers = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1,
          maxScale: 4,
          onInteractionStart: (details) {
            _start = details.focalPoint;
            _end = _start;
            _startedZoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
            _pointers = details.pointerCount;
          },
          onInteractionUpdate: (details) {
            _end = details.focalPoint;
            if (details.pointerCount > _pointers)
              _pointers = details.pointerCount;
          },
          onInteractionEnd: (_) {
            final delta = _end - _start;
            if (!_startedZoomed &&
                _pointers == 1 &&
                _controller.value.getMaxScaleOnAxis() <= 1.01 &&
                delta.dx.abs() > 60 &&
                delta.dx.abs() > delta.dy.abs()) {
              widget.onSwipe(delta.dx < 0 ? 1 : -1);
            }
          },
          child: Center(child: widget.child),
        ),
      );
}
