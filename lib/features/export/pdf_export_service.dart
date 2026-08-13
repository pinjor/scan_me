import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/services/scan_compression.dart';
import '../../core/services/watermark_service.dart';
import '../../shared/models/library_models.dart';

typedef PdfProgress = void Function(int current, int total);

abstract final class PdfExportService {
  PdfExportService._();

  /// Build PDF from already-compressed JPEG page bytes.
  static Future<Uint8List> buildPdfFromJpegs({
    required List<Uint8List> jpegPages,
    PdfPageSizeOption pageSize = PdfPageSizeOption.original,
    PdfOrientationOption orientation = PdfOrientationOption.auto,
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
      final pageFormat = _pageFormat(
        imageW: w,
        imageH: h,
        pageSize: pageSize,
        orientation: orientation,
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

  static PdfPageFormat _pageFormat({
    required int imageW,
    required int imageH,
    required PdfPageSizeOption pageSize,
    required PdfOrientationOption orientation,
  }) {
    final imageLandscape = imageW >= imageH;

    PdfPageFormat base;
    switch (pageSize) {
      case PdfPageSizeOption.letter:
        base = PdfPageFormat.letter;
      case PdfPageSizeOption.a4:
        base = PdfPageFormat.a4;
      case PdfPageSizeOption.original:
        // Match image aspect; long edge ≈ A4 long edge.
        final long = PdfPageFormat.a4.height;
        final short = long * (imageLandscape
            ? imageH / imageW
            : imageW / imageH);
        return imageLandscape
            ? PdfPageFormat(long, short, marginAll: 0)
            : PdfPageFormat(short, long, marginAll: 0);
    }

    final wantLandscape = switch (orientation) {
      PdfOrientationOption.landscape => true,
      PdfOrientationOption.portrait => false,
      PdfOrientationOption.auto => imageLandscape,
    };

    final portrait = PdfPageFormat(
      base.width,
      base.height,
      marginAll: 0,
    );
    final landscape = PdfPageFormat(
      base.height,
      base.width,
      marginAll: 0,
    );
    return wantLandscape ? landscape : portrait;
  }
}

/// Prepare one page for export: compress → rotate → Apptriangle watermark.
Future<Uint8List> prepareExportJpeg({
  required String imagePath,
  required int rotation,
  required bool alreadyCompressed,
  int maxLongEdge = kExportMaxLongEdge,
  int quality = kExportJpegQuality,
}) async {
  var bytes = await File(imagePath).readAsBytes();
  if (!alreadyCompressed) {
    bytes = await ImageCompressionService.compressJpegBytesAsync(
      bytes,
      maxLongEdge: maxLongEdge,
      quality: quality,
    );
  } else if (maxLongEdge != kExportMaxLongEdge ||
      quality != kExportJpegQuality) {
    // Re-encode when user picked a different quality preset.
    bytes = await ImageCompressionService.compressJpegBytesAsync(
      bytes,
      maxLongEdge: maxLongEdge,
      quality: quality,
    );
  }
  final deg = ((rotation % 360) + 360) % 360;
  if (deg != 0) {
    bytes = await compute(_rotateJpeg, (bytes: bytes, degrees: deg, quality: quality));
  }
  return WatermarkService.applyToJpegBytes(bytes);
}

Future<Uint8List> prepareExportImageBytes({
  required String imagePath,
  required int rotation,
  required bool alreadyCompressed,
  required ImageExportFormat format,
  required ImageExportQuality qualityPreset,
}) async {
  final jpeg = await prepareExportJpeg(
    imagePath: imagePath,
    rotation: rotation,
    alreadyCompressed: alreadyCompressed,
    maxLongEdge: qualityPreset.maxLongEdge,
    quality: qualityPreset.jpegQuality,
  );
  if (format == ImageExportFormat.jpg) return jpeg;
  final decoded = img.decodeImage(jpeg);
  if (decoded == null) return jpeg;
  return Uint8List.fromList(img.encodePng(decoded));
}

Uint8List _rotateJpeg(({Uint8List bytes, int degrees, int quality}) msg) {
  final decoded = img.decodeImage(msg.bytes);
  if (decoded == null) return msg.bytes;
  final rotated = img.copyRotate(decoded, angle: msg.degrees);
  return Uint8List.fromList(
    img.encodeJpg(rotated, quality: msg.quality),
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
