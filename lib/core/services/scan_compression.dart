import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Export / processed-page compression policy (readable text, smaller files).
const int kExportMaxLongEdge = 1600;
const int kExportJpegQuality = 82;
const int kThumbMaxLongEdge = 240;
const int kThumbJpegQuality = 70;

abstract final class ImageCompressionService {
  ImageCompressionService._();

  /// Decode via Flutter codec, **downsample only** (never upscale).
  /// Always returns opaque RGB — RGBA/alpha broke CamScan B&W (full-white pages).
  static Future<img.Image> decodeDownsampled(
    Uint8List bytes, {
    int maxLongEdge = kExportMaxLongEdge,
  }) async {
    // Probe intrinsic size without scaling.
    final probe = await ui.instantiateImageCodec(bytes);
    final probeFrame = await probe.getNextFrame();
    final iw = probeFrame.image.width;
    final ih = probeFrame.image.height;
    probeFrame.image.dispose();

    final longEdge = iw > ih ? iw : ih;
    final int? targetW;
    final int? targetH;
    if (longEdge > maxLongEdge) {
      if (iw >= ih) {
        targetW = maxLongEdge;
        targetH = null;
      } else {
        targetW = null;
        targetH = maxLongEdge;
      }
    } else {
      targetW = null;
      targetH = null;
    }

    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    try {
      final bd = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (bd == null) {
        throw StateError('Could not read decoded image bytes');
      }
      final w = uiImage.width;
      final h = uiImage.height;
      final rgba = bd.buffer.asUint8List();
      // Opaque RGB only — do not keep alpha for filter / export pipelines.
      final out = img.Image(width: w, height: h, numChannels: 3);
      var i = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          out.setPixelRgb(x, y, rgba[i], rgba[i + 1], rgba[i + 2]);
          i += 4;
        }
      }
      return resizeIfLarge(out, maxLongEdge);
    } finally {
      uiImage.dispose();
    }
  }

  static Uint8List compressJpegBytes(
    Uint8List bytes, {
    int maxLongEdge = kExportMaxLongEdge,
    int quality = kExportJpegQuality,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw StateError('Could not decode image for compression');
    }
    final resized = resizeIfLarge(decoded, maxLongEdge);
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  static Future<Uint8List> compressJpegBytesAsync(
    Uint8List bytes, {
    int maxLongEdge = kExportMaxLongEdge,
    int quality = kExportJpegQuality,
  }) async {
    try {
      final decoded = await decodeDownsampled(bytes, maxLongEdge: maxLongEdge);
      return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
    } catch (_) {
      if (bytes.length < 200 * 1024) {
        return compressJpegBytes(
          bytes,
          maxLongEdge: maxLongEdge,
          quality: quality,
        );
      }
      return compute(_compressIsolate, (
        bytes: bytes,
        maxLongEdge: maxLongEdge,
        quality: quality,
      ));
    }
  }

  static Uint8List makeThumbnail(Uint8List bytes) {
    return compressJpegBytes(
      bytes,
      maxLongEdge: kThumbMaxLongEdge,
      quality: kThumbJpegQuality,
    );
  }

  static Future<Uint8List> makeThumbnailAsync(Uint8List bytes) {
    return compressJpegBytesAsync(
      bytes,
      maxLongEdge: kThumbMaxLongEdge,
      quality: kThumbJpegQuality,
    );
  }

  static img.Image resizeIfLarge(img.Image src, int maxEdge) {
    final w = src.width;
    final h = src.height;
    final longEdge = w > h ? w : h;
    if (longEdge <= maxEdge) return src;
    final scale = maxEdge / longEdge;
    return img.copyResize(
      src,
      width: (w * scale).round().clamp(1, maxEdge),
      height: (h * scale).round().clamp(1, maxEdge),
      interpolation: img.Interpolation.average,
    );
  }
}

Uint8List _compressIsolate(
  ({Uint8List bytes, int maxLongEdge, int quality}) msg,
) => ImageCompressionService.compressJpegBytes(
  msg.bytes,
  maxLongEdge: msg.maxLongEdge,
  quality: msg.quality,
);
