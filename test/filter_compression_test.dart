import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:scanme/core/services/scan_compression.dart';
import 'package:scanme/features/filters/cam_scan_bw_filter.dart';

Uint8List _sampleJpeg({int w = 200, int h = 280}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(240, 230, 220));
  // Dark ink stroke
  for (var x = 40; x < 160; x++) {
    for (var y = 100; y < 108; y++) {
      im.setPixelRgb(x, y, 20, 20, 20);
    }
  }
  // Pastel watermark midtone
  for (var x = 60; x < 140; x++) {
    for (var y = 140; y < 180; y++) {
      im.setPixelRgb(x, y, 200, 180, 210);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
}

void main() {
  test('compression resizes long edge', () {
    final bytes = _sampleJpeg(w: 2000, h: 2800);
    final out = ImageCompressionService.compressJpegBytes(bytes);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width <= kExportMaxLongEdge, isTrue);
    expect(decoded.height <= kExportMaxLongEdge, isTrue);
  });

  test('B&W filter produces greyscale JPEG', () {
    final bytes = _sampleJpeg();
    final out = CamScanBwFilter.processBytes(bytes, quality: 82);
    expect(out.isNotEmpty, isTrue);
    final decoded = img.decodeImage(out)!;
    final p = decoded.getPixel(100, 104);
    // Ink should stay dark
    expect(p.r, lessThan(80));
  });
}
