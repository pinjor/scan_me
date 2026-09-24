import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanme/core/services/watermark_service.dart';
import 'package:scanme/features/export/pdf_export_service.dart';
import 'package:scanme/shared/models/library_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JPEG watermark changes bottom-right region', () async {
    final page = img.Image(width: 400, height: 560, numChannels: 3);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    final jpeg = Uint8List.fromList(img.encodeJpg(page, quality: 95));
    final stamped = await WatermarkService.applyToJpegBytes(jpeg);
    expect(stamped.length, greaterThan(jpeg.length));
    final out = img.decodeImage(stamped)!;
    // Wide wordmark — sample a band along bottom edge, not one corner pixel.
    var changed = 0;
    for (var x = out.width - 160; x < out.width - 4; x++) {
      for (var y = out.height - 48; y < out.height - 4; y++) {
        final p = out.getPixel(x, y);
        if (p.r.round() < 250 || p.g.round() < 250 || p.b.round() < 250) {
          changed++;
        }
      }
    }
    expect(changed, greaterThan(0));
  });

  test('PDF build embeds baked watermarked pages', () async {
    Uint8List blankJpeg() {
      final page = img.Image(width: 200, height: 280, numChannels: 3);
      img.fill(page, color: img.ColorRgb8(250, 250, 250));
      return Uint8List.fromList(img.encodeJpg(page, quality: 90));
    }

    final stamped = await WatermarkService.applyToJpegBytes(blankJpeg());
    final pdf = await PdfExportService.buildPdfFromJpegs(
      jpegPages: [stamped, stamped, stamped],
      pageSize: PdfPageSizeOption.original,
      drawCornerWatermark: false,
    );
    expect(pdf.length, greaterThan(2000));
    final noWm = await PdfExportService.buildPdfFromJpegs(
      jpegPages: [blankJpeg(), blankJpeg(), blankJpeg()],
      drawCornerWatermark: false,
    );
    expect(pdf.length, greaterThan(noWm.length));
  });
}
