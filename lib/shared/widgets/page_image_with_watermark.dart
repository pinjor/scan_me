import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/text_watermark.dart';

/// How the page image is laid out before placing the watermark on its pixels.
enum PageImageWatermarkLayout {
  /// Full list width; height from image aspect ratio.
  fitWidth,

  /// Letterboxed inside a bounded viewport (Review / PhotoView).
  containInParent,
}

/// Page image with watermark anchored to the **image rect**, not the viewer.
class PageImageWithWatermark extends StatefulWidget {
  const PageImageWithWatermark({
    super.key,
    required this.path,
    this.quarterTurns = 0,
    this.layout = PageImageWatermarkLayout.fitWidth,
    this.filterQuality = FilterQuality.high,
  });

  final String path;
  final int quarterTurns;
  final PageImageWatermarkLayout layout;
  final FilterQuality filterQuality;

  @override
  State<PageImageWithWatermark> createState() => _PageImageWithWatermarkState();
}

class _PageImageWithWatermarkState extends State<PageImageWithWatermark> {
  static final Map<String, Size> _sizeCache = {};

  Size? _displaySize;

  @override
  void initState() {
    super.initState();
    _loadDisplaySize();
  }

  @override
  void didUpdateWidget(PageImageWithWatermark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.quarterTurns != widget.quarterTurns) {
      _displaySize = null;
      _loadDisplaySize();
    }
  }

  Future<void> _loadDisplaySize() async {
    final cached = _sizeCache[widget.path];
    if (cached != null) {
      if (mounted) setState(() => _displaySize = _oriented(cached));
      return;
    }

    final file = File(widget.path);
    if (!await file.exists()) return;

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final raw = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      _sizeCache[widget.path] = raw;
      if (mounted) setState(() => _displaySize = _oriented(raw));
    } catch (_) {
      // Fall back to layout without cached aspect ratio.
    }
  }

  Size _oriented(Size raw) {
    final turns = widget.quarterTurns % 4;
    if (turns.isOdd) return Size(raw.height, raw.width);
    return raw;
  }

  Widget _pageStack({required double width, required double height}) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        fit: StackFit.expand,
        children: [
          Image.file(
            File(widget.path),
            fit: BoxFit.fill,
            filterQuality: widget.filterQuality,
            gaplessPlayback: true,
          ),
          const Positioned(
            right: TextWatermark.previewMargin,
            bottom: TextWatermark.previewMargin,
            child: _Stamp(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.layout) {
      case PageImageWatermarkLayout.fitWidth:
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final size = _displaySize;
            if (size == null || size.width <= 0) {
              return Image.file(
                File(widget.path),
                fit: BoxFit.fitWidth,
                width: width,
                filterQuality: widget.filterQuality,
                gaplessPlayback: true,
              );
            }
            final height = width * (size.height / size.width);
            return _pageStack(width: width, height: height);
          },
        );
      case PageImageWatermarkLayout.containInParent:
        return LayoutBuilder(
          builder: (context, constraints) {
            if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
              return Image.file(
                File(widget.path),
                fit: BoxFit.contain,
                filterQuality: widget.filterQuality,
                gaplessPlayback: true,
              );
            }

            final box = Size(constraints.maxWidth, constraints.maxHeight);
            final size = _displaySize;
            if (size == null || size.width <= 0) {
              return Center(
                child: Image.file(
                  File(widget.path),
                  fit: BoxFit.contain,
                  width: box.width,
                  height: box.height,
                  filterQuality: widget.filterQuality,
                  gaplessPlayback: true,
                ),
              );
            }

            final fitted = applyBoxFit(BoxFit.contain, size, box);
            final dest = fitted.destination;
            final left = (box.width - dest.width) / 2;
            final top = (box.height - dest.height) / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: left,
                  top: top,
                  width: dest.width,
                  height: dest.height,
                  child: _pageStack(width: dest.width, height: dest.height),
                ),
              ],
            );
          },
        );
    }
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp();

  @override
  Widget build(BuildContext context) => TextWatermark.preview();
}
