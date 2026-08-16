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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compression resizes long edge', () {
    final bytes = _sampleJpeg(w: 2000, h: 2800);
    final out = ImageCompressionService.compressJpegBytes(bytes);
    final decoded = img.decodeImage(out)!;
    expect(decoded.width <= kExportMaxLongEdge, isTrue);
    expect(decoded.height <= kExportMaxLongEdge, isTrue);
  });

  test('B&W filter produces greyscale JPEG with dark ink', () {
    final bytes = _sampleJpeg();
    final out = CamScanBwFilter.processBytes(bytes, quality: 82);
    expect(out.isNotEmpty, isTrue);
    final decoded = img.decodeImage(out)!;
    final p = decoded.getPixel(100, 104);
    expect(p.r, lessThan(80));
  });

  test('B&W async must not produce full-white page', () async {
    final bytes = _sampleJpeg(w: 800, h: 1100);
    final out = await CamScanBwFilter.processBytesAsync(bytes, quality: 82);
    final decoded = img.decodeImage(out)!;
    var minV = 255;
    var dark = 0;
    for (var y = 0; y < decoded.height; y++) {
      for (var x = 0; x < decoded.width; x++) {
        final v = decoded.getPixel(x, y).r.round();
        if (v < minV) minV = v;
        if (v < 80) dark++;
      }
    }
    expect(minV, lessThan(80), reason: 'ink must survive async B&W');
    expect(dark, greaterThan(0), reason: 'must have dark pixels');
  });

  test('decodeDownsampled never upscales', () async {
    final bytes = _sampleJpeg(w: 400, h: 600);
    final down = await ImageCompressionService.decodeDownsampled(
      bytes,
      maxLongEdge: 1600,
    );
    expect(down.width, 400);
    expect(down.height, 600);
    expect(down.numChannels, 3);
  });
}
