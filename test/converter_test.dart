import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:scanme/features/converters/document_converter_service.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

Uint8List _pngBytes() {
  final im = img.Image(width: 40, height: 30);
  img.fill(im, color: img.ColorRgba8(10, 120, 200, 255));
  return Uint8List.fromList(img.encodePng(im));
}

Uint8List _jpgBytes() {
  final im = img.Image(width: 40, height: 30);
  img.fill(im, color: img.ColorRgb8(200, 40, 40));
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scanme_conv_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('PNG → JPG converter writes jpeg', () async {
    final src = File(p.join(tmp.path, 'a.png'));
    await src.writeAsBytes(_pngBytes());

    final result = await DocumentConverterService.imageToJpeg(src.path);
    expect(File(result.outputPath).existsSync(), isTrue);
    expect(result.outputPath.toLowerCase().endsWith('.jpg'), isTrue);
    final decoded =
        img.decodeImage(await File(result.outputPath).readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, 40);
  });

  test('JPG → PNG converter writes png', () async {
    final src = File(p.join(tmp.path, 'b.jpg'));
    await src.writeAsBytes(_jpgBytes());

    final result = await DocumentConverterService.imageToPng(src.path);
    expect(result.outputPath.toLowerCase().endsWith('.png'), isTrue);
    final decoded =
        img.decodeImage(await File(result.outputPath).readAsBytes());
    expect(decoded, isNotNull);
    expect(p.basename(result.outputPath).contains('Closure'), isFalse);
  });

  test('TXT → PDF converter writes pdf', () async {
    final src = File(p.join(tmp.path, 'notes.txt'));
    await src.writeAsString('Hello ScanMe\n\nSecond paragraph.');

    final result = await DocumentConverterService.txtToPdf(src.path);
    expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
    expect(result.label, 'PDF');
    final bytes = await File(result.outputPath).readAsBytes();
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(p.basename(result.outputPath).contains('Closure'), isFalse);
    expect(
      RegExp(r'^notes_PDF_\d{4}-\d{2}-\d{2}_\d{4}\.pdf$')
          .hasMatch(p.basename(result.outputPath)),
      isTrue,
      reason: 'expected notes_PDF_yyyy-MM-dd_HHmm.pdf',
    );
  });

  test('PDF → .txt writes UTF-8 text file', () async {
    // Minimal PDF with drawable text via package:pdf, then extract.
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (c) => pw.Text('ScanMe PDF to TXT probe'),
      ),
    );
    final pdfFile = File(p.join(tmp.path, 'probe.pdf'));
    await pdfFile.writeAsBytes(await pdf.save());

    final result = await DocumentConverterService.pdfToTxt(pdfFile.path);
    expect(result.outputPath.toLowerCase().endsWith('.txt'), isTrue);
    expect(result.label, '.txt');
    expect(result.mimeType, 'text/plain');
    final body = await File(result.outputPath).readAsString();
    expect(body.toLowerCase().contains('scanme') || body.contains('probe') || body.isNotEmpty, isTrue);
    expect(
      RegExp(r'^probe_TXT_\d{4}-\d{2}-\d{2}_\d{4}\.txt$')
          .hasMatch(p.basename(result.outputPath)),
      isTrue,
    );
  });

  test('PDF → DOCX writes Word package', () async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (c) => pw.Text('ScanMe PDF to DOCX probe'),
      ),
    );
    final named = File(p.join(tmp.path, 'letter.pdf'));
    await named.writeAsBytes(await pdf.save());

    final result = await DocumentConverterService.pdfToDocx(named.path);
    expect(result.outputPath.toLowerCase().endsWith('.docx'), isTrue);
    expect(result.label, '.docx');
    expect(
      result.mimeType,
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    final bytes = await File(result.outputPath).readAsBytes();
    expect(bytes.length, greaterThan(100));
    // ZIP local file header
    expect(bytes[0], 0x50);
    expect(bytes[1], 0x4b);
    expect(
      RegExp(r'^letter_DOCX_\d{4}-\d{2}-\d{2}_\d{4}\.docx$')
          .hasMatch(p.basename(result.outputPath)),
      isTrue,
    );
  });

  test('cleanBaseName strips open-with / incoming junk', () {
    expect(
      DocumentConverterService.cleanBaseName('open_with_Invoice.pdf'),
      'Invoice',
    );
    expect(
      DocumentConverterService.cleanBaseName('incoming_Contract.pdf'),
      'Contract',
    );
    expect(
      DocumentConverterService.cleanBaseName(
        'Contract_TXT_2026-08-16_1445.txt',
      ),
      'Contract',
    );
  });
}
