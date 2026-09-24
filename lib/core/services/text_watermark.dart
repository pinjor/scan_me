import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../shared/widgets/page_image_with_watermark.dart';

/// ScanMe text watermark — Lobster + Playfair, two left-aligned lines, bottom-right on page.
abstract final class TextWatermark {
  TextWatermark._();

  static const title = 'ScanMe';
  static const subtitle = 'Powered by Apptriangle Limited';

  static const lobsterFamily = 'Lobster';
  static const playfairFamily = 'Playfair Display';

  static const Color ink = Color(0xFF000000);
  /// Light enough that page text underneath stays readable.
  static const double stampOpacity = 0.45;

  /// On-screen preview (Review / Viewer) — title larger than subtitle.
  static const double previewTitleSize = 12;
  static const double previewSubtitleSize = 5.5;
  static const double previewMargin = 10;
  /// Reference width so baked export stamp matches [preview] on screen.
  static const double previewReferenceWidth = 360;

  static bool _flutterFontsReady = false;
  static pw.Font? _pwLobster;
  static pw.Font? _pwPlayfair;
  static final Map<int, img.Image> _rasterCache = {};

  static Future<void> ensureFlutterFonts() async {
    if (_flutterFontsReady) return;
    final lobster = FontLoader(lobsterFamily);
    lobster.addFont(rootBundle.load('fonts/Lobster-Regular.ttf'));
    final playfair = FontLoader(playfairFamily);
    playfair.addFont(rootBundle.load('fonts/PlayfairDisplay.ttf'));
    await Future.wait([lobster.load(), playfair.load()]);
    _flutterFontsReady = true;
  }

  static Future<void> ensurePdfFonts() async {
    if (_pwLobster != null) return;
    _pwLobster = pw.Font.ttf(await rootBundle.load('fonts/Lobster-Regular.ttf'));
    _pwPlayfair =
        pw.Font.ttf(await rootBundle.load('fonts/PlayfairDisplay.ttf'));
  }

  static TextStyle _titleStyle(double size, {double opacity = stampOpacity}) {
    return TextStyle(
      fontFamily: lobsterFamily,
      fontSize: size,
      color: ink.withValues(alpha: opacity),
      height: 1.0,
      fontWeight: FontWeight.w600,
      shadows: const [
        Shadow(color: Color(0x1A000000), offset: Offset(0.2, 0.2), blurRadius: 0),
      ],
    );
  }

  static TextStyle _subtitleStyle(double size, {double opacity = stampOpacity}) {
    return TextStyle(
      fontFamily: playfairFamily,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: ink.withValues(alpha: opacity),
      height: 1.05,
      shadows: const [
        Shadow(color: Color(0x14000000), offset: Offset(0.15, 0.15), blurRadius: 0),
      ],
    );
  }

  /// Two-line stamp for bottom-right of a page (moves with zoom / swipe).
  static Widget preview() {
    return Opacity(
      opacity: stampOpacity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.left,
            style: _titleStyle(previewTitleSize, opacity: 1),
          ),
          const SizedBox(height: 1.5),
          Text(
            subtitle,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.left,
            style: _subtitleStyle(previewSubtitleSize, opacity: 1),
          ),
        ],
      ),
    );
  }

  /// Scroll list / export preview — stamp on page pixels at full width.
  static Widget pageImageFile(
    String path, {
    FilterQuality filterQuality = FilterQuality.high,
  }) {
    return PageImageWithWatermark(
      path: path,
      filterQuality: filterQuality,
      layout: PageImageWatermarkLayout.fitWidth,
    );
  }

  /// Review / zoom host — stamp on letterboxed page rect inside viewport.
  static Widget pageImageInViewport(
    String path, {
    int quarterTurns = 0,
    FilterQuality filterQuality = FilterQuality.high,
  }) {
    return PageImageWithWatermark(
      path: path,
      quarterTurns: quarterTurns,
      filterQuality: filterQuality,
      layout: PageImageWatermarkLayout.containInParent,
    );
  }

  static ({double titleSize, double subtitleSize, double gap}) _exportSizes(
    double pageWidth,
  ) {
    final scale = pageWidth / previewReferenceWidth;
    return (
      titleSize: previewTitleSize * scale,
      subtitleSize: previewSubtitleSize * scale,
      gap: 1.5 * scale,
    );
  }

  /// Rasterize text block for baking onto page JPEGs (matches [preview] scale).
  static Future<img.Image> rasterize({required double pageWidth}) async {
    await ensureFlutterFonts();
    final key = pageWidth.round();
    final cached = _rasterCache[key];
    if (cached != null) return cached;

    final sizes = _exportSizes(pageWidth);
    final layoutW = pageWidth * 0.55;
    final color = ink.withValues(alpha: stampOpacity);

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: _titleStyle(sizes.titleSize).copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: layoutW);

    final subtitlePainter = TextPainter(
      text: TextSpan(
        text: subtitle,
        style: _subtitleStyle(sizes.subtitleSize).copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: layoutW);

    final w = math.max(titlePainter.width, subtitlePainter.width).ceil();
    final h = (titlePainter.height + sizes.gap + subtitlePainter.height).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    );
    titlePainter.paint(canvas, Offset.zero);
    subtitlePainter.paint(
      canvas,
      Offset(0, titlePainter.height + sizes.gap),
    );

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(w, h);
    final bytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    uiImage.dispose();
    if (bytes == null) {
      throw StateError('Could not rasterize text watermark');
    }

    final decoded = img.decodeImage(bytes.buffer.asUint8List());
    if (decoded == null) {
      throw StateError('Could not decode rasterized watermark');
    }
    _rasterCache[key] = decoded;
    return decoded;
  }

  /// PDF overlay block (legacy toolkit paths).
  static pw.Widget pdfBlock({required double pageWidth}) {
    final lobster = _pwLobster;
    final playfair = _pwPlayfair;
    if (lobster == null || playfair == null) {
      throw StateError('Call TextWatermark.ensurePdfFonts() first');
    }
    final sizes = _exportSizes(pageWidth);
    return pw.Opacity(
      opacity: stampOpacity,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              font: lobster,
              fontSize: sizes.titleSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: sizes.gap),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              font: playfair,
              fontSize: sizes.subtitleSize,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

