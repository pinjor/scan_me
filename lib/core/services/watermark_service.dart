import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'scan_compression.dart';

/// Apptriangle logo — small bottom-right stamp on scanned pages.
abstract final class WatermarkService {
  WatermarkService._();

  static const assetPath = 'assets/branding/apptriangle_logo.png';

  /// Logo width ≈ this fraction of page width (small corner mark).
  static const double widthFraction = 0.22;

  /// Margin from edges as fraction of the shorter page side.
  static const double marginFraction = 0.025;

  /// Watermark opacity 0–255.
  static const int opacity = 150;

  static img.Image? _logo;

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

  /// Composite logo onto JPEG/PNG page bytes → JPEG.
  static Future<Uint8List> applyToJpegBytes(Uint8List pageBytes) async {
    final page = img.decodeImage(pageBytes);
    if (page == null) return pageBytes;
    final logo = await _loadLogo();
    final stamped = _composite(page, logo);
    return Uint8List.fromList(
      img.encodeJpg(stamped, quality: kExportJpegQuality),
    );
  }

  static img.Image _composite(img.Image page, img.Image logo) {
    final targetW =
        (page.width * widthFraction).round().clamp(48, page.width ~/ 2);
    final scale = targetW / logo.width;
    final targetH = (logo.height * scale).round().clamp(1, page.height ~/ 3);
    final scaled = img.copyResize(
      logo,
      width: targetW,
      height: targetH,
      interpolation: img.Interpolation.average,
    );

    final margin =
        (page.width < page.height ? page.width : page.height) *
        marginFraction;
    final x = (page.width - scaled.width - margin).round().clamp(0, page.width - 1);
    final y = (page.height - scaled.height - margin)
        .round()
        .clamp(0, page.height - 1);

    // Soften logo toward watermark look.
    for (final p in scaled) {
      final a = (p.a * opacity / 255).round().clamp(0, 255);
      scaled.setPixelRgba(p.x, p.y, p.r.toInt(), p.g.toInt(), p.b.toInt(), a);
    }

    return img.compositeImage(page, scaled, dstX: x, dstY: y);
  }
}
