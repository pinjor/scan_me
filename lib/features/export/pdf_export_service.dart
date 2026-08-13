import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/services/scan_compression.dart';
import '../../core/services/watermark_service.dart';

typedef PdfProgress = void Function(int current, int total);


abstract final class PdfExportService {
  PdfExportService._();

  /// Build PDF from already-compressed JPEG page bytes (no second encode).
  static Future<Uint8List> buildPdfFromJpegs({
    required List<Uint8List> jpegPages,
    PdfProgress? onProgress,
  }) async {
    final doc = pw.Document();
    final total = jpegPages.length;

    for (var i = 0; i < jpegPages.length; i++) {
      onProgress?.call(i + 1, total);
      final bytes = jpegPages[i];
      final decoded = img.decodeImage(bytes);
      final w = decoded?.width ?? 1;
      final h = decoded?.height ?? 1;
      final image = pw.MemoryImage(bytes);

      final pageFormat = w >= h
          ? PdfPageFormat(
              PdfPageFormat.a4.height,
              PdfPageFormat.a4.width,
              marginAll: 0,
            )
          : PdfPageFormat(
              PdfPageFormat.a4.width,
              PdfPageFormat.a4.height,
              marginAll: 0,
            );

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    return doc.save();
  }
}

/// Prepare one page for export: compress → rotate → Apptriangle watermark.
Future<Uint8List> prepareExportJpeg({
  required String imagePath,
  required int rotation,
  required bool alreadyCompressed,
}) async {
  var bytes = await File(imagePath).readAsBytes();
  if (!alreadyCompressed) {
    bytes = await ImageCompressionService.compressJpegBytesAsync(bytes);
  }
  final deg = ((rotation % 360) + 360) % 360;
  if (deg != 0) {
    bytes = await compute(_rotateJpeg, (bytes: bytes, degrees: deg));
  }
  return WatermarkService.applyToJpegBytes(bytes);
}

Uint8List _rotateJpeg(({Uint8List bytes, int degrees}) msg) {
  final decoded = img.decodeImage(msg.bytes);
  if (decoded == null) return msg.bytes;
  final rotated = img.copyRotate(decoded, angle: msg.degrees);
  return Uint8List.fromList(
    img.encodeJpg(rotated, quality: kExportJpegQuality),
  );
}

Uint8List rotateAndThumb(Uint8List bytes, int rotation) {
  var work = bytes;
  final deg = ((rotation % 360) + 360) % 360;
  if (deg != 0) {
    final decoded = img.decodeImage(work);
    if (decoded != null) {
      work = Uint8List.fromList(
        img.encodeJpg(
          img.copyRotate(decoded, angle: deg),
          quality: kExportJpegQuality,
        ),
      );
    }
  }
  return ImageCompressionService.makeThumbnail(work);
}
