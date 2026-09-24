
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

import 'scan_compression.dart';
import 'text_watermark.dart';

/// Text watermark — bottom-right on exports / previews.
abstract final class WatermarkService {
  WatermarkService._();

  /// Margin from edges as fraction of the shorter page side (matches preview).
  static const double marginFraction =
      TextWatermark.previewMargin / TextWatermark.previewReferenceWidth;

  static Future<void> ensurePdfFonts() => TextWatermark.ensurePdfFonts();

  /// Composite text watermark onto JPEG/PNG page bytes → JPEG.
  static Future<Uint8List> applyToJpegBytes(
    Uint8List pageBytes, {
    int quality = kExportJpegQuality,
  }) async {
    final page = img.decodeImage(pageBytes);
    if (page == null) return pageBytes;

    final mark = await TextWatermark.rasterize(pageWidth: page.width.toDouble());
    final stamped = _composite(page, mark);
    return Uint8List.fromList(img.encodeJpg(stamped, quality: quality));
  }

  /// Bottom-right text watermark for `package:pdf` pages (legacy overlay path).
  static pw.Widget pdfCornerMark({
    required double pageWidth,
    required double pageHeight,
  }) {
    final shortSide = pageWidth < pageHeight ? pageWidth : pageHeight;
    final margin = shortSide * marginFraction;
    return pw.Positioned(
      right: margin,
      bottom: margin,
      child: TextWatermark.pdfBlock(pageWidth: pageWidth),
    );
  }

  /// Footer watermark for multi-page PDF toolkits.
  static pw.Widget pdfFooterBlock({required double pageWidth}) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: TextWatermark.pdfBlock(pageWidth: pageWidth),
    );
  }

  static img.Image _composite(img.Image page, img.Image mark) {
    final margin =
        (page.width < page.height ? page.width : page.height) *
        marginFraction;
    final x = (page.width - mark.width - margin).round().clamp(0, page.width);
    final y = (page.height - mark.height - margin).round().clamp(0, page.height);

    // Keep text fully opaque — no fade on baked pixels.
    return img.compositeImage(page, mark, dstX: x, dstY: y);
  }
}
