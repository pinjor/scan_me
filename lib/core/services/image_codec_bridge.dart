
import 'package:flutter/services.dart';

/// Native helpers for formats Dart `image` cannot decode (HEIC/HEIF).
abstract final class ImageCodecBridge {
  ImageCodecBridge._();

  static const _channel = MethodChannel('app.atl.scanme/image_codec');

  /// Decode HEIC/HEIF at [path] to JPEG bytes (quality ~90). Null if unsupported.
  static Future<Uint8List?> heicToJpeg(String path) async {
    try {
      final raw = await _channel.invokeMethod<Uint8List>('heicToJpeg', {
        'path': path,
      });
      return raw;
    } catch (_) {
      return null;
    }
  }
}
