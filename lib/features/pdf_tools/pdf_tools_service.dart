import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Size;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../converters/document_converter_service.dart';
import '../export/pdf_export_service.dart';
import 'pdf_tools_exception.dart';

typedef PdfToolsProgress = void Function(String label, double? progress);

enum PdfCompressPreset { small, balanced, high }

extension PdfCompressPresetX on PdfCompressPreset {
  String get title => switch (this) {
        PdfCompressPreset.small => 'Small',
        PdfCompressPreset.balanced => 'Balanced',
        PdfCompressPreset.high => 'High quality',
      };

  String get subtitle => switch (this) {
        PdfCompressPreset.small => 'Smallest output · lower image quality',
        PdfCompressPreset.balanced => 'Recommended · good quality / size',
        PdfCompressPreset.high => 'Larger file · better visual quality',
      };
}

enum PdfImageExportFormat { jpg, png }

class PdfCompressOutcome {
  const PdfCompressOutcome({
    required this.result,
    required this.originalBytes,
    required this.newBytes,
  });

  final ConvertResult result;
  final int originalBytes;
  final int newBytes;

  int get savedBytes => originalBytes - newBytes;
  double get savedRatio =>
      originalBytes == 0 ? 0 : savedBytes / originalBytes;
}

class PdfRange {
  const PdfRange(this.start, this.end) : assert(start >= 0 && end >= start);

  /// Inclusive 0-based indexes.
  final int start;
  final int end;

  int get length => end - start + 1;
}

/// Offline PDF organize / convert / compress. Original files are never overwritten.
abstract final class PdfToolsService {
  PdfToolsService._();

  static Future<int> pageCount(String path) async {
    final doc = await _openFile(path);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  static Future<ConvertResult> merge({
    required List<String> paths,
    PdfToolsProgress? onProgress,
  }) async {
    if (paths.length < 2) throw PdfToolsException.tooFew();
    final sources = <sf.PdfDocument>[];
    try {
      for (var i = 0; i < paths.length; i++) {
        onProgress?.call('Opening PDF ${i + 1} of ${paths.length}', i / paths.length);
        sources.add(await _openFile(paths[i]));
      }
      final plan = <({sf.PdfDocument doc, int index})>[];
      for (final src in sources) {
        for (var i = 0; i < src.pages.count; i++) {
          plan.add((doc: src, index: i));
        }
      }
      if (plan.isEmpty) throw PdfToolsException.empty();
      final bytes = await _copyPages(plan, onProgress: onProgress);
      return await _writePdf(sourcePath: paths.first, kind: 'MERGE', bytes: bytes);
    } finally {
      for (final s in sources) {
        s.dispose();
      }
    }
  }

  static Future<ConvertResult> extractPages({
    required String path,
    required List<int> indexes,
    String kind = 'EXTRACT',
    PdfToolsProgress? onProgress,
  }) async {
    final unique = indexes.toSet().toList()..sort();
    if (unique.isEmpty) {
      throw const PdfToolsException('Select at least one page.');
    }
    final src = await _openFile(path);
    try {
      _assertIndexes(unique, src.pages.count);
      final plan = [
        for (final i in unique) (doc: src, index: i),
      ];
      final bytes = await _copyPages(plan, onProgress: onProgress);
      return await _writePdf(sourcePath: path, kind: kind, bytes: bytes);
    } finally {
      src.dispose();
    }
  }

  static Future<ConvertResult> reorderPages({
    required String path,
    required List<int> order,
    PdfToolsProgress? onProgress,
  }) async {
    final src = await _openFile(path);
    try {
      if (order.length != src.pages.count) {
        throw const PdfToolsException('Page order does not match this PDF.');
      }
      _assertIndexes(order, src.pages.count);
      if (order.toSet().length != order.length) {
        throw const PdfToolsException('Each page can appear only once.');
      }
      final plan = [
        for (final i in order) (doc: src, index: i),
      ];
      final bytes = await _copyPages(plan, onProgress: onProgress);
      return await _writePdf(sourcePath: path, kind: 'REORDER', bytes: bytes);
    } finally {
      src.dispose();
    }
  }

  static Future<ConvertResult> deletePages({
    required String path,
    required Set<int> indexes,
    PdfToolsProgress? onProgress,
  }) async {
    final src = await _openFile(path);
    try {
      final count = src.pages.count;
      if (indexes.isEmpty) throw PdfToolsException.selectPages();
      _assertIndexes(indexes, count);
      if (indexes.length >= count) throw PdfToolsException.keepOne();
      final keep = [
        for (var i = 0; i < count; i++)
          if (!indexes.contains(i)) i,
      ];
      final plan = [
        for (final i in keep) (doc: src, index: i),
      ];
      final bytes = await _copyPages(plan, onProgress: onProgress);
      return await _writePdf(sourcePath: path, kind: 'PAGES', bytes: bytes);
    } finally {
      src.dispose();
    }
  }

  static Future<ConvertResult> rotatePages({
    required String path,
    required Set<int> indexes,
    required int degrees,
    PdfToolsProgress? onProgress,
  }) async {
    if (degrees % 90 != 0) {
      throw const PdfToolsException('Rotation must be 90, 180, or 270 degrees.');
    }
    final steps = ((degrees ~/ 90) % 4 + 4) % 4;
    final src = await _openFile(path);
    try {
      final count = src.pages.count;
      final target = indexes.isEmpty
          ? List<int>.generate(count, (i) => i)
          : (indexes.toList()..sort());
      _assertIndexes(target, count);
      for (var n = 0; n < target.length; n++) {
        final i = target[n];
        onProgress?.call(
          'Rotating page ${i + 1} of $count',
          (n + 1) / target.length,
        );
        src.pages[i].rotation = _addRotation(src.pages[i].rotation, steps);
        if (n % 4 == 0) await Future<void>.delayed(Duration.zero);
      }
      onProgress?.call('Saving PDF…', 1);
      final bytes = Uint8List.fromList(await src.save());
      return await _writePdf(sourcePath: path, kind: 'ROTATE', bytes: bytes);
    } finally {
      src.dispose();
    }
  }

  static Future<List<ConvertResult>> splitRanges({
    required String path,
    required List<PdfRange> ranges,
    PdfToolsProgress? onProgress,
  }) async {
    if (ranges.isEmpty) {
      throw const PdfToolsException('Add at least one page range.');
    }
    final src = await _openFile(path);
    try {
      final count = src.pages.count;
      final out = <ConvertResult>[];
      for (var r = 0; r < ranges.length; r++) {
        final range = ranges[r];
        if (range.start >= count || range.end >= count) {
          throw PdfToolsException(
            'Range ${range.start + 1}–${range.end + 1} is outside this PDF ($count pages).',
          );
        }
        onProgress?.call(
          'Splitting range ${r + 1} of ${ranges.length}',
          (r + 1) / ranges.length,
        );
        final plan = [
          for (var i = range.start; i <= range.end; i++) (doc: src, index: i),
        ];
        final bytes = await _copyPages(plan);
        out.add(
          await _writePdf(
            sourcePath: path,
            kind: 'SPLIT${(r + 1).toString().padLeft(2, '0')}',
            bytes: bytes,
          ),
        );
      }
      return out;
    } finally {
      src.dispose();
    }
  }

  static Future<List<ConvertResult>> splitEveryPage({
    required String path,
    PdfToolsProgress? onProgress,
  }) async {
    final src = await _openFile(path);
    try {
      final count = src.pages.count;
      if (count < 2) throw PdfToolsException.needPages(min: 2);
      final out = <ConvertResult>[];
      for (var i = 0; i < count; i++) {
        onProgress?.call('Splitting page ${i + 1} of $count', (i + 1) / count);
        final bytes = await _copyPages([(doc: src, index: i)]);
        out.add(
          await _writePdf(
            sourcePath: path,
            kind: 'SPLIT${(i + 1).toString().padLeft(2, '0')}',
            bytes: bytes,
          ),
        );
        if (i % 2 == 0) await Future<void>.delayed(Duration.zero);
      }
      return out;
    } finally {
      src.dispose();
    }
  }

  static Future<List<ConvertResult>> pdfToImages({
    required String path,
    required List<int> indexes,
    required PdfImageExportFormat format,
    required int quality,
    required double dpi,
    PdfToolsProgress? onProgress,
  }) async {
    final unique = indexes.toSet().toList()..sort();
    if (unique.isEmpty) {
      throw const PdfToolsException('Select at least one page.');
    }
    final count = await pageCount(path);
    _assertIndexes(unique, count);
    final pdfBytes = await File(path).readAsBytes();
    final rasters = <int, Uint8List>{};
    var done = 0;
    await for (final page in Printing.raster(
      pdfBytes,
      pages: unique,
      dpi: dpi,
    )) {
      rasters[unique[done]] = await page.toPng();
      done++;
      onProgress?.call(
        'Exporting page $done of ${unique.length}',
        done / unique.length,
      );
    }
    if (rasters.length != unique.length) {
      throw const PdfToolsException(
        "Couldn't render this PDF as images on this device.",
      );
    }
    final out = <ConvertResult>[];
    for (var n = 0; n < unique.length; n++) {
      final i = unique[n];
      var bytes = rasters[i]!;
      var ext = 'png';
      var mime = 'image/png';
      var kind = 'PNG';
      if (format == PdfImageExportFormat.jpg) {
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw const PdfToolsException("Couldn't encode a page as JPEG.");
        }
        bytes = Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
        ext = 'jpg';
        mime = 'image/jpeg';
        kind = 'JPG';
      }
      final file = await DocumentConverterService.createOutputFile(
        sourcePath: path,
        kind: '$kind${(n + 1).toString().padLeft(2, '0')}',
        ext: ext,
      );
      await file.writeAsBytes(bytes, flush: true);
      out.add(
        ConvertResult(
          outputPath: file.path,
          label: '.$ext',
          mimeType: mime,
        ),
      );
    }
    return out;
  }

  /// Native zlib compress. Optionally rasterize if that yields a smaller file.
  static Future<PdfCompressOutcome> compress({
    required String path,
    required PdfCompressPreset preset,
    bool allowRaster = true,
    PdfToolsProgress? onProgress,
  }) async {
    final original = await File(path).readAsBytes();
    onProgress?.call('Compressing PDF…', 0.2);
    final native = await _nativeCompress(original, preset);
    var best = native.length <= original.length ? native : original;

    if (allowRaster && preset != PdfCompressPreset.high) {
      onProgress?.call('Trying a smaller image pass…', 0.55);
      try {
        final rastered = await _rasterCompress(original, preset, onProgress);
        if (rastered.length < best.length) best = rastered;
      } catch (_) {
        // Keep native/original — raster is optional.
      }
    }

    if (best.length > original.length) best = original;
    onProgress?.call('Saving…', 1);
    final result = await _writePdf(
      sourcePath: path,
      kind: 'COMPRESS',
      bytes: best,
    );
    return PdfCompressOutcome(
      result: result,
      originalBytes: original.length,
      newBytes: best.length,
    );
  }

  static Future<ConvertResult> imagesToPdf({
    required List<String> imagePaths,
    PdfToolsProgress? onProgress,
  }) async {
    if (imagePaths.isEmpty) {
      throw const PdfToolsException('Choose at least one image.');
    }
    final jpegs = <Uint8List>[];
    for (var i = 0; i < imagePaths.length; i++) {
      onProgress?.call(
        'Preparing image ${i + 1} of ${imagePaths.length}',
        (i + 1) / (imagePaths.length + 1),
      );
      final jpeg = await prepareExportJpeg(
        imagePath: imagePaths[i],
        rotation: 0,
        alreadyCompressed: false,
        applyWatermark: false,
      );
      jpegs.add(jpeg);
    }
    onProgress?.call('Building PDF…', 0.95);
    final bytes = await PdfExportService.buildPdfFromJpegs(
      jpegPages: jpegs,
      drawCornerWatermark: true,
    );
    return _writePdf(
      sourcePath: imagePaths.first,
      kind: 'PDF',
      bytes: bytes,
    );
  }

  static Future<Map<int, Uint8List>> thumbnails({
    required String path,
    required List<int> indexes,
    double dpi = 72,
  }) async {
    if (indexes.isEmpty) return {};
    final unique = indexes.toList();
    final pdfBytes = await File(path).readAsBytes();
    final out = <int, Uint8List>{};
    var n = 0;
    await for (final page in Printing.raster(
      pdfBytes,
      pages: unique,
      dpi: dpi,
    )) {
      if (n >= unique.length) break;
      out[unique[n]] = await page.toPng();
      n++;
    }
    return out;
  }

  static String friendlySize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static Future<sf.PdfDocument> _openFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const PdfToolsException("Couldn't find that file.");
    }
    final bytes = await file.readAsBytes();
    return _openBytes(bytes);
  }

  static sf.PdfDocument _openBytes(Uint8List bytes) {
    if (bytes.length < 5 ||
        String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw PdfToolsException.invalid();
    }
    try {
      final doc = sf.PdfDocument(inputBytes: bytes);
      if (doc.pages.count <= 0) {
        doc.dispose();
        throw PdfToolsException.empty();
      }
      return doc;
    } on PdfToolsException {
      rethrow;
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('password') || s.contains('encrypt')) {
        throw PdfToolsException.password();
      }
      throw PdfToolsException.invalid();
    }
  }

  static void _assertIndexes(Iterable<int> indexes, int count) {
    for (final i in indexes) {
      if (i < 0 || i >= count) {
        throw PdfToolsException(
          'Page ${i + 1} is outside this PDF ($count pages).',
        );
      }
    }
  }

  static sf.PdfPageRotateAngle _addRotation(
    sf.PdfPageRotateAngle current,
    int steps,
  ) {
    final next = (current.index + steps) % 4;
    return sf.PdfPageRotateAngle.values[next];
  }

  static Future<Uint8List> _copyPages(
    List<({sf.PdfDocument doc, int index})> plan, {
    PdfToolsProgress? onProgress,
  }) async {
    final dest = sf.PdfDocument();
    dest.pageSettings.setMargins(0);
    try {
      for (var i = 0; i < plan.length; i++) {
        onProgress?.call(
          'Copying page ${i + 1} of ${plan.length}',
          (i + 1) / plan.length,
        );
        final srcPage = plan[i].doc.pages[plan[i].index];
        final size = srcPage.size;
        final template = srcPage.createTemplate();
        final section = dest.sections!.add();
        var pageSize = Size(size.width, size.height);
        if (srcPage.rotation == sf.PdfPageRotateAngle.rotateAngle90 ||
            srcPage.rotation == sf.PdfPageRotateAngle.rotateAngle270) {
          pageSize = Size(size.height, size.width);
        }
        section.pageSettings.size = pageSize;
        section.pageSettings.setMargins(0);
        section.pageSettings.rotate = srcPage.rotation;
        final destPage = section.pages.add();
        destPage.rotation = srcPage.rotation;
        destPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          size,
        );
        if (i % 3 == 0) await Future<void>.delayed(Duration.zero);
      }
      return Uint8List.fromList(await dest.save());
    } finally {
      dest.dispose();
    }
  }

  static Future<Uint8List> _nativeCompress(
    Uint8List original,
    PdfCompressPreset preset,
  ) async {
    final doc = _openBytes(original);
    try {
      doc.compressionLevel = switch (preset) {
        PdfCompressPreset.small => sf.PdfCompressionLevel.best,
        PdfCompressPreset.balanced => sf.PdfCompressionLevel.best,
        PdfCompressPreset.high => sf.PdfCompressionLevel.aboveNormal,
      };
      return Uint8List.fromList(await doc.save());
    } finally {
      doc.dispose();
    }
  }

  static Future<Uint8List> _rasterCompress(
    Uint8List original,
    PdfCompressPreset preset,
    PdfToolsProgress? onProgress,
  ) async {
    final dpi = switch (preset) {
      PdfCompressPreset.small => 96.0,
      PdfCompressPreset.balanced => 130.0,
      PdfCompressPreset.high => 160.0,
    };
    final quality = switch (preset) {
      PdfCompressPreset.small => 52,
      PdfCompressPreset.balanced => 72,
      PdfCompressPreset.high => 85,
    };
    final src = _openBytes(original);
    final srcCount = src.pages.count;
    src.dispose();
    final jpegs = <Uint8List>[];
    var n = 0;
    await for (final page in Printing.raster(original, dpi: dpi)) {
      n++;
      onProgress?.call('Rebuilding page $n of $srcCount', n / srcCount);
      final png = await page.toPng();
      final decoded = img.decodeImage(png);
      if (decoded == null) {
        throw const PdfToolsException("Couldn't compress this PDF.");
      }
      jpegs.add(
        Uint8List.fromList(img.encodeJpg(decoded, quality: quality)),
      );
    }
    if (jpegs.length != srcCount) {
      throw const PdfToolsException("Couldn't compress this PDF.");
    }
    return PdfExportService.buildPdfFromJpegs(
      jpegPages: jpegs,
      drawCornerWatermark: false,
    );
  }

  static Future<ConvertResult> _writePdf({
    required String sourcePath,
    required String kind,
    required Uint8List bytes,
  }) async {
    final file = await DocumentConverterService.createOutputFile(
      sourcePath: sourcePath,
      kind: kind,
      ext: 'pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    return ConvertResult(
      outputPath: file.path,
      label: 'PDF · ${p.basename(file.path)}',
      mimeType: 'application/pdf',
    );
  }
}
