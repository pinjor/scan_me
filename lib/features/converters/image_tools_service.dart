import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'document_converter_service.dart';

/// Offline image edit: resize (pixels), compress (file size), save crop bytes.
abstract final class ImageToolsService {
  ImageToolsService._();

  static Future<({int width, int height, int bytes})> probe(
    String path,
  ) async {
    final file = File(path);
    final size = await file.length();
    final decoded = await DocumentConverterService.decodeAnyImage(path);
    return (width: decoded.width, height: decoded.height, bytes: size);
  }

  /// Scale so longest edge ≤ [maxLongEdge] (or exact width/height if set).
  static Future<ConvertResult> resizePixels({
    required String imagePath,
    int? maxLongEdge,
    int? width,
    int? height,
    String format = 'jpg',
    int quality = 90,
  }) async {
    final src = await DocumentConverterService.decodeAnyImage(imagePath);
    img.Image out = src;

    if (width != null && height != null) {
      out = img.copyResize(
        src,
        width: width,
        height: height,
        interpolation: img.Interpolation.average,
      );
    } else if (maxLongEdge != null && maxLongEdge > 0) {
      final long = math.max(src.width, src.height);
      if (long > maxLongEdge) {
        final scale = maxLongEdge / long;
        out = img.copyResize(
          src,
          width: (src.width * scale).round().clamp(1, 100000),
          height: (src.height * scale).round().clamp(1, 100000),
          interpolation: img.Interpolation.average,
        );
      }
    }

    return _encode(
      sourcePath: imagePath,
      image: out,
      format: format,
      quality: quality,
      kind: 'RESIZE',
    );
  }

  /// Reduce file size by lowering JPEG quality until under [targetBytes] (best effort).
  static Future<ConvertResult> compressToSize({
    required String imagePath,
    required int targetBytes,
    int minQuality = 35,
  }) async {
    final src = await DocumentConverterService.decodeAnyImage(imagePath);
    var quality = 88;
    Uint8List encoded = Uint8List.fromList(
      img.encodeJpg(src, quality: quality),
    );

    while (encoded.lengthInBytes > targetBytes && quality > minQuality) {
      quality -= 8;
      encoded = Uint8List.fromList(img.encodeJpg(src, quality: quality));
    }

    // Still too big → also shrink dimensions.
    var working = src;
    var guard = 0;
    while (encoded.lengthInBytes > targetBytes && guard < 6) {
      guard++;
      working = img.copyResize(
        working,
        width: (working.width * 0.85).round().clamp(64, 100000),
        height: (working.height * 0.85).round().clamp(64, 100000),
        interpolation: img.Interpolation.average,
      );
      encoded = Uint8List.fromList(img.encodeJpg(working, quality: quality));
    }

    final out = await DocumentConverterService.createOutputFile(
      sourcePath: imagePath,
      kind: 'COMPRESS',
      ext: 'jpg',
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'JPEG',
      mimeType: 'image/jpeg',
    );
  }

  /// Persist cropped image bytes (from crop UI) as JPG/PNG.
  static Future<ConvertResult> saveCroppedBytes({
    required String sourcePath,
    required Uint8List croppedBytes,
    String format = 'jpg',
    int quality = 92,
  }) async {
    final decoded = img.decodeImage(croppedBytes);
    if (decoded == null) {
      throw StateError('Could not read cropped image.');
    }
    return _encode(
      sourcePath: sourcePath,
      image: decoded,
      format: format,
      quality: quality,
      kind: 'CROP',
    );
  }

  static Future<ConvertResult> _encode({
    required String sourcePath,
    required img.Image image,
    required String format,
    required int quality,
    required String kind,
  }) async {
    final fmt = format.toLowerCase();
    late Uint8List bytes;
    late String ext;
    late String label;
    late String mime;

    switch (fmt) {
      case 'png':
        bytes = Uint8List.fromList(img.encodePng(image));
        ext = 'png';
        label = 'PNG';
        mime = 'image/png';
      case 'webp':
        bytes = Uint8List.fromList(img.encodeWebP(image));
        ext = 'webp';
        label = 'WebP';
        mime = 'image/webp';
      default:
        final flat = img.Image(
          width: image.width,
          height: image.height,
          numChannels: 3,
        );
        img.fill(flat, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(flat, image);
        bytes = Uint8List.fromList(img.encodeJpg(flat, quality: quality));
        ext = 'jpg';
        label = 'JPEG';
        mime = 'image/jpeg';
    }

    final out = await DocumentConverterService.createOutputFile(
      sourcePath: sourcePath,
      kind: kind,
      ext: ext,
    );
    await out.writeAsBytes(bytes, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: label,
      mimeType: mime,
    );
  }

  static String friendlySize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  static String suggestName(String path) =>
      DocumentConverterService.cleanBaseName(path);
}
