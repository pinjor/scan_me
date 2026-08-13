import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/services/scan_compression.dart';
import '../../shared/models/scanned_document.dart';

/// CamScan B&W — exact SLI proposal-form constants + integer math.
abstract final class CamScanBwFilter {
  CamScanBwFilter._();

  static const int maxEdge = kExportMaxLongEdge;
  static const int jpegQuality = kExportJpegQuality;
  static const int adaptiveHalfWindow = 26;
  static const num adaptiveSubtract = 12;
  static const int softBand = 30;
  static const int colorDesatPct = 78;
  static const int whiteWashPct = 90;
  static const int inkFloor = 70;
  static const int washCeil = 215;
  static const int midLiftPct = 80;
  static const int watermarkClearFloor = 115;
  static const int paperMeanFloor = 128;
  static const int chromaWashStart = 8;
  static const int chromaWashFull = 42;
  static const int chromaWashBoostPct = 95;
  static const int localContrastPct = 0;
  static const int localContrastHalf = 1;
  static const int bgNormHalfWindow = 48;
  static const int bgNearMeanSlack = 36;
  static const int bgNearMeanLiftPct = 88;

  static Uint8List processBytes(
    Uint8List bytes, {
    int quality = jpegQuality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image bytes');
    }
    var im = ImageCompressionService.resizeIfLarge(decoded, maxEdge);
    im = _fadeColorsForFormWatermark(im);
    im = img.grayscale(im);
    im = _backgroundNormalize(im);
    im = _localContrastBoost(im);
    im = _softAdaptiveThreshold(
      im,
      halfWindow: adaptiveHalfWindow,
      subtract: adaptiveSubtract,
      softBand: softBand,
    );
    return Uint8List.fromList(img.encodeJpg(im, quality: quality));
  }

  static Future<Uint8List> processBytesAsync(
    Uint8List bytes, {
    int quality = jpegQuality,
  }) {
    if (bytes.length < 250 * 1024) {
      return Future.value(processBytes(bytes, quality: quality));
    }
    return compute(_bwIsolate, (bytes: bytes, quality: quality));
  }
}

Uint8List _bwIsolate(({Uint8List bytes, int quality}) msg) =>
    CamScanBwFilter.processBytes(msg.bytes, quality: msg.quality);

abstract final class DocumentFilterEngine {
  DocumentFilterEngine._();

  /// Apply [filter] to original bytes. Returns JPEG bytes (compressed).
  static Future<Uint8List> apply({
    required Uint8List originalBytes,
    required PageFilter filter,
  }) async {
    switch (filter) {
      case PageFilter.original:
        return ImageCompressionService.compressJpegBytesAsync(originalBytes);
      case PageFilter.blackAndWhite:
        return CamScanBwFilter.processBytesAsync(originalBytes);
    }
  }
}

int _chroma(int r, int g, int b) {
  final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return mx - mn;
}

img.Image _fadeColorsForFormWatermark(img.Image src) {
  final w = src.width;
  final h = src.height;
  final out = img.Image(width: w, height: h, numChannels: src.numChannels);
  final washSpan =
      (CamScanBwFilter.washCeil - CamScanBwFilter.inkFloor).clamp(1, 255);
  final desat = CamScanBwFilter.colorDesatPct;
  final wash = CamScanBwFilter.whiteWashPct;
  final inkFloor = CamScanBwFilter.inkFloor;
  final chromaStart = CamScanBwFilter.chromaWashStart;
  final chromaFull = CamScanBwFilter.chromaWashFull;
  final chromaSpan = (chromaFull - chromaStart).clamp(1, 255);
  final chromaBoost = CamScanBwFilter.chromaWashBoostPct;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final px = src.getPixel(x, y);
      var r = px.r.round();
      var g = px.g.round();
      var b = px.b.round();
      final chroma = _chroma(r, g, b);
      final y0 = (r * 299 + g * 587 + b * 114) ~/ 1000;
      r = r + (y0 - r) * desat ~/ 100;
      g = g + (y0 - g) * desat ~/ 100;
      b = b + (y0 - b) * desat ~/ 100;
      final y1 = (r * 299 + g * 587 + b * 114) ~/ 1000;
      final t = ((y1 - inkFloor) * 100 ~/ washSpan).clamp(0, 100);
      var amount = wash * t * t ~/ 10000;
      if (chroma > chromaStart && y1 > inkFloor) {
        final cT = ((chroma - chromaStart) * 100 ~/ chromaSpan).clamp(0, 100);
        amount = (amount + chromaBoost * cT * t ~/ 10000).clamp(0, 100);
      }
      r = r + (255 - r) * amount ~/ 100;
      g = g + (255 - g) * amount ~/ 100;
      b = b + (255 - b) * amount ~/ 100;
      var y2 = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (y2 > inkFloor) {
        final lift =
            CamScanBwFilter.midLiftPct *
            ((y2 - inkFloor) * 100 ~/ washSpan).clamp(0, 100) ~/
            100;
        y2 = y2 + (255 - y2) * lift ~/ 100;
      }
      out.setPixelRgb(x, y, y2, y2, y2);
    }
  }
  return out;
}

img.Image _backgroundNormalize(img.Image src) {
  final w = src.width;
  final h = src.height;
  final half = CamScanBwFilter.bgNormHalfWindow;
  final slack = CamScanBwFilter.bgNearMeanSlack;
  final inkFloor = CamScanBwFilter.inkFloor;
  final nearLift = CamScanBwFilter.bgNearMeanLiftPct;

  final gray = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      gray[y * w + x] = src.getPixel(x, y).r.round();
    }
  }

  final sat = List.generate(h + 1, (_) => List<int>.filled(w + 1, 0));
  for (var y = 1; y <= h; y++) {
    for (var x = 1; x <= w; x++) {
      sat[y][x] =
          gray[(y - 1) * w + (x - 1)] +
          sat[y - 1][x] +
          sat[y][x - 1] -
          sat[y - 1][x - 1];
    }
  }

  final out = img.Image(width: w, height: h, numChannels: src.numChannels);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final xa = _clampInt(x - half, 0, w - 1);
      final xb = _clampInt(x + half, 0, w - 1);
      final ya = _clampInt(y - half, 0, h - 1);
      final yb = _clampInt(y + half, 0, h - 1);
      final sum =
          sat[yb + 1][xb + 1] - sat[ya][xb + 1] - sat[yb + 1][xa] + sat[ya][xa];
      final area = (xb - xa + 1) * (yb - ya + 1);
      final mean = (sum ~/ area).clamp(1, 255);
      final g = gray[y * w + x];
      var n = ((g * 255) ~/ mean).clamp(0, 255);
      if (g >= inkFloor && (mean - g).abs() <= slack) {
        n = 255;
      } else if (g >= inkFloor && g >= mean - (slack * 2 ~/ 3)) {
        n = (n + (255 - n) * nearLift ~/ 100).clamp(0, 255);
      }
      out.setPixelRgb(x, y, n, n, n);
    }
  }
  return out;
}

img.Image _localContrastBoost(img.Image src) {
  final w = src.width;
  final h = src.height;
  final half = CamScanBwFilter.localContrastHalf;
  final pct = CamScanBwFilter.localContrastPct;
  if (pct <= 0 || half < 0) return src;

  final gray = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      gray[y * w + x] = src.getPixel(x, y).r.round();
    }
  }

  final sat = List.generate(h + 1, (_) => List<int>.filled(w + 1, 0));
  for (var y = 1; y <= h; y++) {
    for (var x = 1; x <= w; x++) {
      sat[y][x] =
          gray[(y - 1) * w + (x - 1)] +
          sat[y - 1][x] +
          sat[y][x - 1] -
          sat[y - 1][x - 1];
    }
  }

  final out = img.Image(width: w, height: h, numChannels: src.numChannels);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final xa = _clampInt(x - half, 0, w - 1);
      final xb = _clampInt(x + half, 0, w - 1);
      final ya = _clampInt(y - half, 0, h - 1);
      final yb = _clampInt(y + half, 0, h - 1);
      final sum =
          sat[yb + 1][xb + 1] - sat[ya][xb + 1] - sat[yb + 1][xa] + sat[ya][xa];
      final area = (xb - xa + 1) * (yb - ya + 1);
      final mean = sum ~/ area;
      final g = gray[y * w + x];
      final boosted = (g + (g - mean) * pct ~/ 100).clamp(0, 255);
      out.setPixelRgb(x, y, boosted, boosted, boosted);
    }
  }
  return out;
}

img.Image _softAdaptiveThreshold(
  img.Image src, {
  required int halfWindow,
  required num subtract,
  required int softBand,
}) {
  final w = src.width;
  final h = src.height;
  final gray = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      gray[y * w + x] = src.getPixel(x, y).r.round();
    }
  }

  final sat = List.generate(h + 1, (_) => List<int>.filled(w + 1, 0));
  for (var y = 1; y <= h; y++) {
    for (var x = 1; x <= w; x++) {
      sat[y][x] =
          gray[(y - 1) * w + (x - 1)] +
          sat[y - 1][x] +
          sat[y][x - 1] -
          sat[y - 1][x - 1];
    }
  }

  final denom = (2 * softBand).clamp(1, 512);
  final clearFloor = CamScanBwFilter.watermarkClearFloor;
  final paperMean = CamScanBwFilter.paperMeanFloor;
  final out = img.Image(width: w, height: h, numChannels: src.numChannels);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final xa = _clampInt(x - halfWindow, 0, w - 1);
      final xb = _clampInt(x + halfWindow, 0, w - 1);
      final ya = _clampInt(y - halfWindow, 0, h - 1);
      final yb = _clampInt(y + halfWindow, 0, h - 1);
      final sum =
          sat[yb + 1][xb + 1] - sat[ya][xb + 1] - sat[yb + 1][xa] + sat[ya][xa];
      final area = (xb - xa + 1) * (yb - ya + 1);
      final mean = sum / area;
      final diff = gray[y * w + x] - (mean - subtract);
      final int v0;
      if (diff >= softBand) {
        v0 = 255;
      } else if (diff <= -softBand) {
        v0 = 0;
      } else {
        v0 = ((diff + softBand) * 255 / denom).round().clamp(0, 255);
      }
      final v = (v0 >= clearFloor && mean >= paperMean) ? 255 : v0;
      out.setPixelRgb(x, y, v, v, v);
    }
  }
  return out;
}

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
