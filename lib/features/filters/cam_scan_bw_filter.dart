
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/services/scan_compression.dart';
import '../../shared/models/scanned_document.dart';

/// CamScan B&W — same SLI pipeline, softened constants (less crush / more detail).
/// Spec baseline: `docs/PROPOSAL_FORM_BW_CAMSCAN_SPEC.md`.
///
/// Applied to **every scanned / imported page** by default (editor auto-B&W).
///
/// Resolution/JPEG are higher than generic export (1600/q82): adaptive threshold
/// + low JPEG looks pixelated when Review zooms the page.
abstract final class CamScanBwFilter {
  CamScanBwFilter._();

  /// Keep sharpness without 2800px CamScan cost (was slowing Preparing/filter).
  static const int maxEdge = 2200;
  /// Near-binary pages need decent JPEG quality or DCT blocks read as pixels.
  static const int jpegQuality = 92;
  // Softened vs SLI proposal-form (was 26/12/30) — milder threshold, keep ink.
  static const int adaptiveHalfWindow = 26;
  static const num adaptiveSubtract = 8;
  static const int softBand = 48;
  static const int colorDesatPct = 65;
  static const int whiteWashPct = 68;
  static const int inkFloor = 70;
  static const int washCeil = 215;
  static const int midLiftPct = 55;
  static const int watermarkClearFloor = 140;
  static const int paperMeanFloor = 128;
  static const int chromaWashStart = 8;
  static const int chromaWashFull = 42;
  static const int chromaWashBoostPct = 70;
  static const int localContrastPct = 0;
  static const int localContrastHalf = 1;
  static const int bgNormHalfWindow = 48;
  static const int bgNearMeanSlack = 26;
  static const int bgNearMeanLiftPct = 65;

  /// Sync path — used by tests and isolate. Matches SLI `processBlackAndWhiteBytes`.
  static Uint8List processBytes(
    Uint8List bytes, {
    int quality = jpegQuality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image bytes');
    }
    // Always work in opaque RGB — RGBA/alpha-0 from Flutter codec whites out ink.
    var im = _asOpaqueRgb(decoded);
    im = _resizeForBw(im);
    im = _fadeColorsForFormWatermark(im);
    im = img.grayscale(im);
    im = _backgroundNormalize(im);
    im = _localContrastBoost(im); // no-op while localContrastPct == 0
    im = _softAdaptiveThreshold(
      im,
      halfWindow: adaptiveHalfWindow,
      subtract: adaptiveSubtract,
      softBand: softBand,
    );
    return Uint8List.fromList(img.encodeJpg(im, quality: quality));
  }

  /// Linear downsample — cubic was too slow on multi-page prepare.
  static img.Image _resizeForBw(img.Image src) {
    final w = src.width;
    final h = src.height;
    final longEdge = w > h ? w : h;
    if (longEdge <= maxEdge) return src;
    final scale = maxEdge / longEdge;
    return img.copyResize(
      src,
      width: (w * scale).round().clamp(1, maxEdge),
      height: (h * scale).round().clamp(1, maxEdge),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Always isolate — keeps UI free while CamScan runs.
  static Future<Uint8List> processBytesAsync(
    Uint8List bytes, {
    int quality = jpegQuality,
  }) {
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
      case PageFilter.grayscale:
      case PageFilter.autoEnhance:
      case PageFilter.vivid:
      case PageFilter.lighten:
        return PageLookFilters.processAsync(originalBytes, filter);
    }
  }
}

/// Extra enhance looks (greyscale / auto / vivid / lighten).
abstract final class PageLookFilters {
  PageLookFilters._();

  static Future<Uint8List> processAsync(
    Uint8List bytes,
    PageFilter filter,
  ) async {
    if (bytes.length < 250 * 1024) {
      return processBytes(bytes, filter);
    }
    return compute(_lookIsolate, (bytes: bytes, filter: filter.wire));
  }

  static Uint8List processBytes(Uint8List bytes, PageFilter filter) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image bytes');
    }
    var im = _asOpaqueRgb(decoded);
    im = ImageCompressionService.resizeIfLarge(im, kExportMaxLongEdge);
    im = switch (filter) {
      PageFilter.grayscale => img.grayscale(im),
      PageFilter.autoEnhance => _autoEnhance(im),
      PageFilter.vivid => _vivid(im),
      PageFilter.lighten => _lighten(im),
      _ => im,
    };
    return Uint8List.fromList(
      img.encodeJpg(im, quality: kExportJpegQuality),
    );
  }
}

Uint8List _lookIsolate(({Uint8List bytes, String filter}) msg) =>
    PageLookFilters.processBytes(
      msg.bytes,
      PageFilterX.fromWire(msg.filter),
    );

img.Image _autoEnhance(img.Image src) {
  // Mild contrast + paper lift — keeps color, punches text.
  final w = src.width;
  final h = src.height;
  final out = img.Image(width: w, height: h, numChannels: 3);
  var sum = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      sum += (p.r.round() * 299 + p.g.round() * 587 + p.b.round() * 114) ~/
          1000;
    }
  }
  final mean = sum ~/ (w * h);
  final bias = (128 - mean).clamp(-40, 40);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      var r = p.r.round();
      var g = p.g.round();
      var b = p.b.round();
      r = ((r - 128) * 118 ~/ 100 + 128 + bias).clamp(0, 255);
      g = ((g - 128) * 118 ~/ 100 + 128 + bias).clamp(0, 255);
      b = ((b - 128) * 118 ~/ 100 + 128 + bias).clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

img.Image _vivid(img.Image src) {
  final w = src.width;
  final h = src.height;
  final out = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      var r = p.r.round();
      var g = p.g.round();
      var b = p.b.round();
      final y0 = (r * 299 + g * 587 + b * 114) ~/ 1000;
      // Push away from grey (saturate) then mild contrast.
      r = (r + (r - y0) * 35 ~/ 100).clamp(0, 255);
      g = (g + (g - y0) * 35 ~/ 100).clamp(0, 255);
      b = (b + (b - y0) * 35 ~/ 100).clamp(0, 255);
      r = ((r - 128) * 112 ~/ 100 + 128).clamp(0, 255);
      g = ((g - 128) * 112 ~/ 100 + 128).clamp(0, 255);
      b = ((b - 128) * 112 ~/ 100 + 128).clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

img.Image _lighten(img.Image src) {
  final w = src.width;
  final h = src.height;
  final out = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      var r = p.r.round();
      var g = p.g.round();
      var b = p.b.round();
      // Lift midtones toward paper white; keep dark ink.
      final y0 = (r * 299 + g * 587 + b * 114) ~/ 1000;
      if (y0 > 55) {
        final t = ((y0 - 55) * 100 ~/ 200).clamp(0, 100);
        final lift = 55 * t ~/ 100;
        r = (r + (255 - r) * lift ~/ 100).clamp(0, 255);
        g = (g + (255 - g) * lift ~/ 100).clamp(0, 255);
        b = (b + (255 - b) * lift ~/ 100).clamp(0, 255);
      }
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}

/// Force opaque 3-channel RGB so getPixel / grayscale match SLI / Kotlin.
img.Image _asOpaqueRgb(img.Image src) {
  if (src.numChannels == 3 && src.format == img.Format.uint8) {
    return src;
  }
  final out = img.Image(width: src.width, height: src.height, numChannels: 3);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      out.setPixelRgb(x, y, p.r.round(), p.g.round(), p.b.round());
    }
  }
  return out;
}

int _chroma(int r, int g, int b) {
  final mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  final mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return mx - mn;
}

img.Image _fadeColorsForFormWatermark(img.Image src) {
  final w = src.width;
  final h = src.height;
  final out = img.Image(width: w, height: h, numChannels: 3);
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

  final out = img.Image(width: w, height: h, numChannels: 3);
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

  final out = img.Image(width: w, height: h, numChannels: 3);
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
  final out = img.Image(width: w, height: h, numChannels: 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final xa = _clampInt(x - halfWindow, 0, w - 1);
      final xb = _clampInt(x + halfWindow, 0, w - 1);
      final ya = _clampInt(y - halfWindow, 0, h - 1);
      final yb = _clampInt(y + halfWindow, 0, h - 1);
      final sum =
          sat[yb + 1][xb + 1] - sat[ya][xb + 1] - sat[yb + 1][xa] + sat[ya][xa];
      final area = (xb - xa + 1) * (yb - ya + 1);
      // Same as SLI Dart: float local mean (Kotlin uses int mean — within JPEG noise).
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
