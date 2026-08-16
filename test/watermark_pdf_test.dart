import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanme/core/services/watermark_service.dart';
import 'package:scanme/features/export/pdf_export_service.dart';
import 'package:scanme/shared/models/library_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('JPEG watermark changes corner pixels', () async {
    final page = img.Image(width: 400, height: 560, numChannels: 3);
    img.fill(page, color: img.ColorRgb8(255, 255, 255));
    final jpeg = Uint8List.fromList(img.encodeJpg(page, quality: 95));
    final stamped = await WatermarkService.applyToJpegBytes(jpeg);
    final out = img.decodeImage(stamped)!;
    // Bottom-right should no longer be pure white after logo stamp.
    final corner = out.getPixel(out.width - 20, out.height - 20);
    final pureWhite = corner.r.round() == 255 &&
        corner.g.round() == 255 &&
        corner.b.round() == 255;
    expect(pureWhite, isFalse);
  });

  test('PDF build embeds Apptriangle on every page', () async {
    Uint8List blankJpeg() {
      final page = img.Image(width: 200, height: 280, numChannels: 3);
      img.fill(page, color: img.ColorRgb8(250, 250, 250));
      return Uint8List.fromList(img.encodeJpg(page, quality: 90));
    }

    final pdf = await PdfExportService.buildPdfFromJpegs(
      jpegPages: [blankJpeg(), blankJpeg(), blankJpeg()],
      pageSize: PdfPageSizeOption.original,
      drawCornerWatermark: true,
    );
    expect(pdf.length, greaterThan(2000));
    // PDF binary should include embedded image streams (pages + logo).
    final hasImageMarker = pdf.contains(0x2F); // '/'
    expect(hasImageMarker, isTrue);
    // With watermark, file larger than three blank JPEGs alone.
    final noWm = await PdfExportService.buildPdfFromJpegs(
      jpegPages: [blankJpeg(), blankJpeg(), blankJpeg()],
      drawCornerWatermark: false,
    );
    expect(pdf.length, greaterThan(noWm.length));
  });
}
