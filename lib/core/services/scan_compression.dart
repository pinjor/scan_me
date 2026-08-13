import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Export / processed-page compression policy (readable text, smaller files).
const int kExportMaxLongEdge = 1600;
const int kExportJpegQuality = 82;
const int kThumbMaxLongEdge = 240;
const int kThumbJpegQuality = 70;

abstract final class ImageCompressionService {
  ImageCompressionService._();

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
  }) {
    if (bytes.length < 200 * 1024) {
      return Future.value(
        compressJpegBytes(bytes, maxLongEdge: maxLongEdge, quality: quality),
      );
    }
    return compute(_compressIsolate, (
      bytes: bytes,
      maxLongEdge: maxLongEdge,
      quality: quality,
    ));
  }

  static Uint8List makeThumbnail(Uint8List bytes) {
    return compressJpegBytes(
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
