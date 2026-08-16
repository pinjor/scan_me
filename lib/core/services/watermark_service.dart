
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

import 'scan_compression.dart';

/// Apptriangle logo — small bottom-right stamp on every exported page / PDF page.
abstract final class WatermarkService {
  WatermarkService._();

  static const assetPath = 'assets/branding/apptriangle_logo.png';

  /// Logo width ≈ this fraction of page width (corner mark).
  static const double widthFraction = 0.24;

  /// Margin from edges as fraction of the shorter page side.
  static const double marginFraction = 0.028;

  /// Watermark opacity 0–255 (baked into pixels).
  static const int opacity = 180;

  /// PDF overlay opacity 0–1.
  static const double pdfOpacity = 0.72;

  static img.Image? _logo;
  static Uint8List? _logoPngBytes;
  static pw.MemoryImage? _pdfLogo;

  static Future<img.Image> _loadLogo() async {
    if (_logo != null) return _logo!;
    final data = await rootBundle.load(assetPath);
    final decoded = img.decodeImage(data.buffer.asUint8List());
    if (decoded == null) {
      throw StateError('Could not decode watermark logo');
    }
    _logo = decoded;
    return decoded;
  }

  static Future<Uint8List> logoPngBytes() async {
    if (_logoPngBytes != null) return _logoPngBytes!;
    final data = await rootBundle.load(assetPath);
    _logoPngBytes = data.buffer.asUint8List();
    return _logoPngBytes!;
  }

  /// Cached PDF logo image for drawing on every page.
  static Future<pw.MemoryImage> pdfLogoImage() async {
    if (_pdfLogo != null) return _pdfLogo!;
    _pdfLogo = pw.MemoryImage(await logoPngBytes());
    return _pdfLogo!;
  }

  /// Composite logo onto JPEG/PNG page bytes → JPEG (visible in any image/PDF
  /// that embeds these pixels).
  static Future<Uint8List> applyToJpegBytes(Uint8List pageBytes) async {
    final page = img.decodeImage(pageBytes);
    if (page == null) return pageBytes;
    final logo = await _loadLogo();
    final stamped = _composite(page, logo);
    return Uint8List.fromList(
      img.encodeJpg(stamped, quality: kExportJpegQuality),
    );
  }

  /// Corner watermark widget for `package:pdf` pages (any PDF viewer).
  static pw.Widget pdfCornerMark({
    required pw.MemoryImage logo,
    required double pageWidth,
    required double pageHeight,
  }) {
    final shortSide = pageWidth < pageHeight ? pageWidth : pageHeight;
    final logoW = pageWidth * widthFraction;
    final margin = shortSide * marginFraction;
    return pw.Positioned(
      right: margin,
      bottom: margin,
      child: pw.Opacity(
        opacity: pdfOpacity,
        child: pw.Image(logo, width: logoW, fit: pw.BoxFit.contain),
      ),
    );
  }

  static img.Image _composite(img.Image page, img.Image logo) {
    final maxW = (page.width ~/ 2).clamp(1, page.width);
    var targetW = (page.width * widthFraction).round();
    if (targetW < 24) targetW = 24;
    if (targetW > maxW) targetW = maxW;
    final scale = targetW / logo.width;
    var targetH = (logo.height * scale).round();
    if (targetH < 1) targetH = 1;
    final maxH = (page.height ~/ 3).clamp(1, page.height);
    if (targetH > maxH) targetH = maxH;
    final scaled = img.copyResize(
      logo,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );

    final margin =
        (page.width < page.height ? page.width : page.height) *
        marginFraction;
    final x =
        (page.width - scaled.width - margin).round().clamp(0, page.width - 1);
    final y = (page.height - scaled.height - margin)
        .round()
        .clamp(0, page.height - 1);

    for (final p in scaled) {
      final a = (p.a.toInt() * opacity / 255).round().clamp(0, 255);
      scaled.setPixelRgba(
        p.x,
        p.y,
        p.r.toInt(),
        p.g.toInt(),
        p.b.toInt(),
        a,
      );
    }

    return img.compositeImage(page, scaled, dstX: x, dstY: y);
  }
}
