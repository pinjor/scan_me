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

import '../../core/services/image_codec_bridge.dart';
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
    // Prior convert outputs: Contract_TXT_2026-08-16_1445 or …_144532
    base = base.replaceFirst(
      RegExp(
        r'_(TXT|PDF|JPG|PNG|WEBP|GIF|CSV|DOCX|XLSX|CROP|RESIZE|COMPRESS|MERGE|SPLIT|EXTRACT|ROTATE|REORDER|PAGES)_\d{4}-\d{2}-\d{2}_\d{4,6}(?:-\d+)?$',
      ),
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
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  /// Output format: `Contract_TXT_2026-08-16_1445.txt`
  static Future<File> createOutputFile({
    required String sourcePath,
    required String kind,
    required String ext,
  }) =>
      _outFile(sourcePath: sourcePath, kind: kind, ext: ext);

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

    // Same-second collision → append -2, -3…
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
    var n = 2;
    while (await file.exists() && n < 100) {
      file = File(
        p.join(dir.path, 'incoming_${base}_${_timeStamp()}-$n$ext'),
      );
      n++;
    }
    if (await file.exists()) {
      file = File(
        p.join(
          dir.path,
          'incoming_${base}_${DateTime.now().millisecondsSinceEpoch}$ext',
        ),
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
    final text = await _extractPdfPlainText(pdfPath);
    final out = await _outFile(
      sourcePath: pdfPath,
      kind: 'TXT',
      ext: 'txt',
    );
    final txtPath = out.path.toLowerCase().endsWith('.txt')
        ? out.path
        : '${out.path}.txt';
    final txtFile = File(txtPath);
    await txtFile.writeAsString(text, encoding: utf8, flush: true);
    return ConvertResult(
      outputPath: txtFile.path,
      label: '.txt',
      mimeType: 'text/plain',
    );
  }

  /// PDF → Word (.docx) via text extraction (layout not preserved; no OCR).
  static Future<ConvertResult> pdfToDocx(String pdfPath) async {
    final text = await _extractPdfPlainText(pdfPath);
    final bytes = _buildMinimalDocx(text);
    final out = await _outFile(
      sourcePath: pdfPath,
      kind: 'DOCX',
      ext: 'docx',
    );
    await out.writeAsBytes(bytes, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: '.docx',
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
  }

  static Future<String> _extractPdfPlainText(String pdfPath) async {
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
        return 'No extractable text found in this PDF.\n'
            'Scanned or image-only pages need OCR (not available offline here).\n';
      }
      return buffer.toString();
    } finally {
      document.dispose();
    }
  }

  /// Minimal OOXML package — paragraphs from plain text (editable in Word).
  static Uint8List _buildMinimalDocx(String plainText) {
    final paragraphs = plainText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');

    final body = StringBuffer();
    for (final line in paragraphs) {
      final escaped = _xmlEscape(line);
      if (line.trim().isEmpty) {
        body.write('<w:p/>');
      } else {
        body.write(
          '<w:p><w:r><w:t xml:space="preserve">$escaped</w:t></w:r></w:p>',
        );
      }
    }

    const contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    const rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    const docRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final archive = Archive();
    void add(String name, String content) {
      final data = utf8.encode(content);
      archive.addFile(ArchiveFile(name, data.length, data));
    }

    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);
    add('word/_rels/document.xml.rels', docRels);

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');

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

  static Future<ConvertResult> imageToPng(String imagePath) async {
    final decoded = await decodeAnyImage(imagePath);
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

  static Future<ConvertResult> imageToJpeg(
    String imagePath, {
    int quality = 90,
  }) async {
    final decoded = await decodeAnyImage(imagePath);
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

  /// Decode JPG/PNG/WebP/GIF via `image`, HEIC via native bridge.
  static Future<img.Image> decodeAnyImage(String imagePath) async {
    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded != null) return decoded;

    final ext = p.extension(imagePath).toLowerCase();
    if (ext == '.heic' || ext == '.heif') {
      final jpeg = await ImageCodecBridge.heicToJpeg(imagePath);
      if (jpeg != null) {
        final fromHeic = img.decodeImage(jpeg);
        if (fromHeic != null) return fromHeic;
      }
    }
    throw StateError('Could not decode image.');
  }

  static Future<ConvertResult> imageToWebp(String imagePath) async {
    final decoded = await decodeAnyImage(imagePath);
    final encoded = Uint8List.fromList(img.encodeWebP(decoded));
    final out = await _outFile(
      sourcePath: imagePath,
      kind: 'WEBP',
      ext: 'webp',
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'WebP',
      mimeType: 'image/webp',
    );
  }

  static Future<ConvertResult> imageToGif(String imagePath) async {
    final decoded = await decodeAnyImage(imagePath);
    final encoded = Uint8List.fromList(img.encodeGif(decoded));
    final out = await _outFile(
      sourcePath: imagePath,
      kind: 'GIF',
      ext: 'gif',
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'GIF',
      mimeType: 'image/gif',
    );
  }

  static Future<ConvertResult> heicToJpeg(String imagePath) async {
    return imageToJpeg(imagePath, quality: 92);
  }

  /// Word (.docx) → PDF (text extraction; no full layout fidelity).
  static Future<ConvertResult> docxToPdf(String docxPath) async {
    final bytes = await File(docxPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw StateError('Not a valid .docx file.');
    }
    final xml = XmlDocument.parse(utf8.decode(docFile.content as List<int>));
    final paragraphs = <String>[];
    for (final pNode in xml.findAllElements('p', namespaceUri: '*')) {
      final parts = pNode
          .findAllElements('t', namespaceUri: '*')
          .map((t) => t.innerText)
          .join();
      final line = parts.trim();
      if (line.isNotEmpty) paragraphs.add(line);
    }
    if (paragraphs.isEmpty) {
      throw StateError('No readable text in this Word file.');
    }

    final logo = await WatermarkService.pdfLogoImage();
    final format = PdfPageFormat.a4;
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 56),
        build: (context) => [
          for (final block in paragraphs)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                block,
                style: const pw.TextStyle(fontSize: 12, lineSpacing: 2),
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
      sourcePath: docxPath,
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

  /// Excel (.xlsx) → CSV (first sheet) + optional PDF table.
  static Future<ConvertResult> xlsxToCsv(String xlsxPath) async {
    final table = await _xlsxFirstSheet(xlsxPath);
    final buffer = StringBuffer();
    for (final row in table) {
      buffer.writeln(
        row.map(_csvEscape).join(','),
      );
    }
    final out = await _outFile(
      sourcePath: xlsxPath,
      kind: 'CSV',
      ext: 'csv',
    );
    await out.writeAsString(buffer.toString(), encoding: utf8, flush: true);
    return ConvertResult(
      outputPath: out.path,
      label: 'CSV',
      mimeType: 'text/csv',
    );
  }

  static Future<ConvertResult> xlsxToPdf(String xlsxPath) async {
    final table = await _xlsxFirstSheet(xlsxPath);
    if (table.isEmpty) {
      throw StateError('Spreadsheet is empty.');
    }
    final logo = await WatermarkService.pdfLogoImage();
    final format = PdfPageFormat.a4.landscape;
    final pdf = pw.Document();
    final colCount = table.map((r) => r.length).fold<int>(0, (a, b) => a > b ? a : b);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: table.first,
            data: table.length > 1 ? table.sublist(1) : const <List<String>>[],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              for (var i = 0; i < colCount; i++)
                i: const pw.FlexColumnWidth(1),
            },
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Opacity(
            opacity: WatermarkService.pdfOpacity,
            child: pw.Image(logo, width: format.width * 0.1),
          ),
        ),
      ),
    );
    final out = await _outFile(
      sourcePath: xlsxPath,
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

  static String _csvEscape(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  static Future<List<List<String>>> _xlsxFirstSheet(String xlsxPath) async {
    final bytes = await File(xlsxPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final shared = <String>[];
    final ss = archive.findFile('xl/sharedStrings.xml');
    if (ss != null) {
      final xml = XmlDocument.parse(utf8.decode(ss.content as List<int>));
      for (final si in xml.findAllElements('si', namespaceUri: '*')) {
        final text = si
            .findAllElements('t', namespaceUri: '*')
            .map((t) => t.innerText)
            .join();
        shared.add(text);
      }
    }

    ArchiveFile? sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    sheetFile ??= archive.files.cast<ArchiveFile?>().firstWhere(
          (f) =>
              f != null &&
              f.isFile &&
              RegExp(r'xl/worksheets/sheet\d+\.xml$', caseSensitive: false)
                  .hasMatch(f.name.replaceAll('\\', '/')),
          orElse: () => null,
        );
    if (sheetFile == null) {
      throw StateError('No worksheet found in this Excel file.');
    }

    final sheetXml =
        XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
    final rows = <List<String>>[];
    for (final row in sheetXml.findAllElements('row', namespaceUri: '*')) {
      final cells = <String>[];
      for (final c in row.findAllElements('c', namespaceUri: '*')) {
        final type = c.getAttribute('t');
        final v = c.getElement('v', namespaceUri: '*')?.innerText ?? '';
        if (type == 's') {
          final idx = int.tryParse(v) ?? -1;
          cells.add(idx >= 0 && idx < shared.length ? shared[idx] : v);
        } else {
          cells.add(v);
        }
      }
      if (cells.any((e) => e.trim().isNotEmpty)) rows.add(cells);
    }
    if (rows.isEmpty) {
      throw StateError('Spreadsheet is empty.');
    }
    return rows;
  }
}
