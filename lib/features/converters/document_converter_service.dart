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

class ConvertResult {
  ConvertResult({
    required this.outputPath,
    required this.label,
  });

  final String outputPath;
  final String label;
}

/// Offline converters: PDF→TXT, PPTX→PDF (text/images best-effort), PNG↔JPG.
abstract final class DocumentConverterService {
  DocumentConverterService._();

  static Future<Directory> _outDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'converts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _stamp() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static Future<ConvertResult> pdfToTxt(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    final document = sf.PdfDocument(inputBytes: bytes);
    try {
      final text = sf.PdfTextExtractor(document).extractText().trim();
      final base = p.basenameWithoutExtension(pdfPath);
      final out = File(
        p.join((await _outDir()).path, '${base}_$_stamp().txt'),
      );
      final body = text.isEmpty
          ? '(No extractable text found. Scanned/image-only PDFs need OCR.)\n'
          : '$text\n';
      await out.writeAsString(body, flush: true);
      return ConvertResult(outputPath: out.path, label: 'Text file');
    } finally {
      document.dispose();
    }
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
          try {
            images.add(pw.MemoryImage(data));
          } catch (_) {}
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
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
            return widgets;
          },
        ),
      );
    }

    final base = p.basenameWithoutExtension(pptxPath);
    final out = File(
      p.join((await _outDir()).path, '${base}_$_stamp().pdf'),
    );
    await out.writeAsBytes(await pdf.save(), flush: true);
    return ConvertResult(outputPath: out.path, label: 'PDF');
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
    // Flatten transparency onto white for JPG.
    final flat = img.Image(
      width: decoded.width,
      height: decoded.height,
      numChannels: 3,
    );
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    final encoded = Uint8List.fromList(img.encodeJpg(flat, quality: quality));
    final base = p.basenameWithoutExtension(imagePath);
    final out = File(
      p.join((await _outDir()).path, '${base}_$_stamp().jpg'),
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(outputPath: out.path, label: 'JPEG');
  }

  static Future<ConvertResult> imageToPng(String imagePath) async {
    final raw = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw StateError('Could not decode image.');
    }
    final encoded = Uint8List.fromList(img.encodePng(decoded));
    final base = p.basenameWithoutExtension(imagePath);
    final out = File(
      p.join((await _outDir()).path, '${base}_$_stamp().png'),
    );
    await out.writeAsBytes(encoded, flush: true);
    return ConvertResult(outputPath: out.path, label: 'PNG');
  }
}
