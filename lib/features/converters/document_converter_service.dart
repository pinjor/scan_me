import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xml/xml.dart';

import '../../core/services/watermark_service.dart';

class ConvertResult {
  ConvertResult({
    required this.outputPath,
    required this.label,
    this.mimeType,
  });

  final String outputPath;
  final String label;
  final String? mimeType;
}

/// Offline converters: PDF↔TXT, PPTX→PDF, PNG↔JPG.
abstract final class DocumentConverterService {
  DocumentConverterService._();

  static Future<Directory> _outDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'converts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Strip open-with / materialize / old stamp junk from a source filename.
  static String cleanBaseName(String pathOrName) {
    var base = p.basenameWithoutExtension(pathOrName);
    if (base.startsWith('open_with_')) {
      base = base.substring('open_with_'.length);
    }
    if (base.startsWith('incoming_')) {
      base = base.substring('incoming_'.length);
    }
    base = base.replaceFirst(RegExp(r'^_?src_\d+_'), '');
    // Prior convert outputs: Contract_TXT_2026-08-16_1445
    base = base.replaceFirst(
      RegExp(r'_(TXT|PDF|JPG|PNG)_\d{4}-\d{2}-\d{2}_\d{4}$'),
      '',
    );
    // Legacy millis suffix: name_1723800000123
    base = base.replaceFirst(RegExp(r'_\d{10,}$'), '');
    base = base
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (base.isEmpty) return 'ScanMe';
    return base;
  }

  static String _timeStamp([DateTime? at]) {
    final now = at ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}-${two(now.month)}-${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
  }

  /// Output format: `Contract_TXT_2026-08-16_1445.txt`
  static Future<File> _outFile({
    required String sourcePath,
    required String kind,
    required String ext,
  }) async {
    final base = cleanBaseName(sourcePath);
    final normalizedExt = ext.startsWith('.') ? ext.substring(1) : ext;
    final dir = await _outDir();
    var candidate = File(
      p.join(dir.path, '${base}_${kind}_${_timeStamp()}.$normalizedExt'),
    );
    if (!await candidate.exists()) return candidate;

    // Same-minute collision → append -2, -3…
    for (var i = 2; i < 100; i++) {
      candidate = File(
        p.join(
          dir.path,
          '${base}_${kind}_${_timeStamp()}-$i.$normalizedExt',
        ),
      );
      if (!await candidate.exists()) return candidate;
    }
    return File(
      p.join(
        dir.path,
        '${base}_${kind}_${DateTime.now().millisecondsSinceEpoch}.$normalizedExt',
      ),
    );
  }

  /// Write picker bytes when SAF returns null [path].
  /// Format: `incoming_Contract.pdf`
  static Future<String> materializePath({
    required String preferredName,
    required Uint8List bytes,
  }) async {
    final dir = await _outDir();
    final ext = p.extension(preferredName);
    final base = cleanBaseName(preferredName);
    var file = File(p.join(dir.path, 'incoming_$base$ext'));
    if (await file.exists()) {
      file = File(
        p.join(dir.path, 'incoming_${base}_${_timeStamp()}$ext'),
      );
    }
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Extract selectable text from [pdfPath] into a UTF-8 `.txt` file.
  ///
  /// Uses Syncfusion page-by-page extraction with [layoutText] so line breaks
  /// survive. Image-only / scanned PDFs yield a short notice (no OCR).
  static Future<ConvertResult> pdfToTxt(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = sf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = sf.PdfTextExtractor(document);
      final pageCount = document.pages.count;
      final buffer = StringBuffer();
      var anyText = false;

      for (var i = 0; i < pageCount; i++) {
        final pageText = extractor
            .extractText(
              startPageIndex: i,
              endPageIndex: i,
              layoutText: true,
            )
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .trimRight();

        if (pageCount > 1) {
          if (i > 0) buffer.writeln();
          buffer.writeln('===== Page ${i + 1} of $pageCount =====');
          buffer.writeln();
        }

        if (pageText.trim().isEmpty) {
          buffer.writeln('(No extractable text on this page.)');
        } else {
          anyText = true;
          buffer.writeln(pageText);
        }
      }

      if (!anyText) {
        buffer
          ..clear()
          ..writeln(
            'No extractable text found in this PDF.',
          )
          ..writeln(
            'Scanned or image-only pages need OCR (not available offline here).',
          );
      }

      final out = await _outFile(
        sourcePath: pdfPath,
        kind: 'TXT',
        ext: 'txt',
      );
      // Force .txt even if base somehow had a weird name.
      final txtPath = out.path.toLowerCase().endsWith('.txt')
          ? out.path
          : '${out.path}.txt';
      final txtFile = File(txtPath);
      await txtFile.writeAsString(
        buffer.toString(),
        encoding: utf8,
        flush: true,
      );
      return ConvertResult(
        outputPath: txtFile.path,
        label: '.txt',
        mimeType: 'text/plain',
      );
    } finally {
      document.dispose();
    }
  }

  /// Plain text → multi-page A4 PDF (wrapped paragraphs) + Apptriangle mark.
  static Future<ConvertResult> txtToPdf(String txtPath) async {
    final raw = await File(txtPath).readAsString();
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (text.isEmpty) {
      throw StateError('Text file is empty.');
    }

    final logo = await WatermarkService.pdfLogoImage();
    final format = PdfPageFormat.a4;
    final pdf = pw.Document();
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();
    final blocks = paragraphs.isEmpty ? <String>[text] : paragraphs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
        build: (context) => [
          for (final block in blocks)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                block,
                style: const pw.TextStyle(
                  fontSize: 12,
                  lineSpacing: 2,
                  color: PdfColors.black,
                ),
              ),
            ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Opacity(
            opacity: WatermarkService.pdfOpacity,
            child: pw.Image(logo, width: format.width * 0.12),
          ),
        ),
      ),
    );

    final out = await _outFile(
      sourcePath: txtPath,
      kind: 'PDF',
      ext: 'pdf',
    );
    await out.writeAsBytes(await pdf.save(), flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  static Future<ConvertResult> pptxToPdf(String pptxPath) async {
    final bytes = await File(pptxPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slides = archive.files
        .where(
          (f) =>
              f.isFile &&
              RegExp(r'^ppt/slides/slide\d+\.xml$', caseSensitive: false)
                  .hasMatch(f.name.replaceAll('\\', '/')),
        )
        .toList()
      ..sort((a, b) {
        final na = int.tryParse(
              RegExp(r'slide(\d+)', caseSensitive: false)
                      .firstMatch(a.name)
                      ?.group(1) ??
                  '',
            ) ??
            0;
        final nb = int.tryParse(
              RegExp(r'slide(\d+)', caseSensitive: false)
                      .firstMatch(b.name)
                      ?.group(1) ??
                  '',
            ) ??
            0;
        return na.compareTo(nb);
      });

    if (slides.isEmpty) {
      throw StateError('No slides found in this PowerPoint file.');
    }

    final media = <String, Uint8List>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      if (name.startsWith('ppt/media/')) {
        media[p.basename(name).toLowerCase()] = Uint8List.fromList(f.content);
      }
    }

    final logo = await WatermarkService.pdfLogoImage();
    final pdf = pw.Document();
    for (final slideFile in slides) {
      final xml = XmlDocument.parse(
        String.fromCharCodes(slideFile.content as List<int>),
      );
      final texts = xml
          .descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final slideName = p.basename(slideFile.name);
      final relPath = 'ppt/slides/_rels/$slideName.xml.rels';
      final images = <pw.MemoryImage>[];
      ArchiveFile? relFile;
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name.replaceAll('\\', '/').toLowerCase() ==
            relPath.toLowerCase()) {
          relFile = f;
          break;
        }
      }

      if (relFile != null) {
        final relXml = XmlDocument.parse(
          String.fromCharCodes(relFile.content as List<int>),
        );
        for (final rel in relXml.findAllElements('Relationship')) {
          final target = rel.getAttribute('Target') ?? '';
          if (!target.contains('media/')) continue;
          final key = p.basename(target).toLowerCase();
          final data = media[key];
          if (data == null) continue;
          final pdfImage = _toPdfImage(data);
          if (pdfImage != null) images.add(pdfImage);
        }
      }

      final format = PdfPageFormat.a4;
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            final widgets = <pw.Widget>[];
            if (texts.isEmpty && images.isEmpty) {
              widgets.add(
                pw.Text(
                  '(Empty slide)',
                  style: const pw.TextStyle(
                    color: PdfColors.grey600,
                    fontSize: 12,
                  ),
                ),
              );
            }
            for (final t in texts) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(t, style: const pw.TextStyle(fontSize: 14)),
                ),
              );
            }
            for (final im in images) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  child: pw.Center(
                    child: pw.Image(im, height: 280, fit: pw.BoxFit.contain),
                  ),
                ),
              );
            }
            return pw.Stack(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: widgets,
                ),
                WatermarkService.pdfCornerMark(
                  logo: logo,
                  pageWidth: format.width,
                  pageHeight: format.height,
                ),
              ],
            );
          },
        ),
      );
    }

    final out = await _outFile(
      sourcePath: pptxPath,
      kind: 'PDF',
      ext: 'pdf',
    );
    await out.writeAsBytes(await pdf.save(), flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'PDF',
      mimeType: 'application/pdf',
    );
  }

  /// Decode arbitrary image bytes → JPEG/PNG for `package:pdf`.
  static pw.MemoryImage? _toPdfImage(Uint8List data) {
    try {
      return pw.MemoryImage(data);
    } catch (_) {
      final decoded = img.decodeImage(data);
      if (decoded == null) return null;
      final jpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
      try {
        return pw.MemoryImage(jpg);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<ConvertResult> imageToJpeg(
    String imagePath, {
    int quality = 90,
  }) async {
    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw StateError('Could not decode image.');
    }
    final flat = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    var encoded = Uint8List.fromList(img.encodeJpg(flat, quality: quality));
    encoded = await WatermarkService.applyToJpegBytes(encoded);
    final out = await _outFile(
      sourcePath: imagePath,
      kind: 'JPG',
      ext: 'jpg',
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'JPEG',
      mimeType: 'image/jpeg',
    );
  }

  static Future<ConvertResult> imageToPng(String imagePath) async {
    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw StateError('Could not decode image.');
    }
    // Stamp via JPEG corner mark, then re-encode PNG.
    var jpeg = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
    jpeg = await WatermarkService.applyToJpegBytes(jpeg);
    final stamped = img.decodeImage(jpeg) ?? decoded;
    final encoded = Uint8List.fromList(img.encodePng(stamped));
    final out = await _outFile(
      sourcePath: imagePath,
      kind: 'PNG',
      ext: 'png',
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'PNG',
      mimeType: 'image/png',
    );
  }
}
