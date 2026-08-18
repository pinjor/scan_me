import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:scanme/features/converters/document_converter_service.dart';

import 'support/converter_fixtures.dart';

typedef _ImgConv = Future<ConvertResult> Function(String path);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scanme_conv_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> srcImage(String ext) async {
    final bytes = switch (ext) {
      'png' => ConverterFixtures.pngBytes(),
      'jpg' => ConverterFixtures.jpgBytes(),
      'webp' => ConverterFixtures.webpBytes(),
      'gif' => ConverterFixtures.gifBytes(),
      _ => throw ArgumentError(ext),
    };
    return ConverterFixtures.writeImage(tmp, 'src.$ext', bytes);
  }

  Future<void> expectImageOut(
    ConvertResult result, {
    required String ext,
    String? label,
  }) async {
    expect(File(result.outputPath).existsSync(), isTrue);
    expect(result.outputPath.toLowerCase().endsWith('.$ext'), isTrue);
    if (label != null) expect(result.label, label);
    final decoded =
        img.decodeImage(await File(result.outputPath).readAsBytes());
    expect(decoded, isNotNull);
    expect(decoded!.width, greaterThan(0));
  }

  group('cleanBaseName', () {
    test('strips open-with / incoming / prior stamps', () {
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
      expect(
        DocumentConverterService.cleanBaseName(
          'Contract_TXT_2026-08-16_144532.txt',
        ),
        'Contract',
      );
      expect(
        DocumentConverterService.cleanBaseName('_src_1_photo.jpg'),
        'photo',
      );
    });
  });

  group('materializePath', () {
    test('writes incoming_ file', () async {
      final path = await DocumentConverterService.materializePath(
        preferredName: 'shot.png',
        bytes: ConverterFixtures.pngBytes(),
      );
      expect(File(path).existsSync(), isTrue);
      expect(p.basename(path), startsWith('incoming_'));
      expect(path.toLowerCase().endsWith('.png'), isTrue);
    });
  });

  group('documents', () {
    test('TXT → PDF · short', () async {
      final src = await ConverterFixtures.writeTxt(tmp);
      final result = await DocumentConverterService.txtToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
      expect(result.label, 'PDF');
      final bytes = await File(result.outputPath).readAsBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(
        RegExp(r'^notes_PDF_\d{4}-\d{2}-\d{2}_\d{4,6}\.pdf$')
            .hasMatch(p.basename(result.outputPath)),
        isTrue,
      );
    });

    test('TXT → PDF · long multiline', () async {
      final body = List.generate(40, (i) => 'Line $i - ScanMe').join('\n');
      final src = await ConverterFixtures.writeTxt(
        tmp,
        name: 'long.txt',
        body: body,
      );
      final result = await DocumentConverterService.txtToPdf(src.path);
      final bytes = await File(result.outputPath).readAsBytes();
      expect(bytes.length, greaterThan(200));
    });

    test('PDF → .txt · single page', () async {
      final pdfFile = await ConverterFixtures.writePdf(tmp);
      final result = await DocumentConverterService.pdfToTxt(pdfFile.path);
      expect(result.outputPath.toLowerCase().endsWith('.txt'), isTrue);
      expect(result.label, '.txt');
      expect(result.mimeType, 'text/plain');
      final body = await File(result.outputPath).readAsString();
      expect(body.isNotEmpty, isTrue);
    });

    test('PDF → .txt · multi page', () async {
      final pdfFile = await ConverterFixtures.writePdf(
        tmp,
        name: 'multi.pdf',
        text: 'ScanMe multi',
        pages: 3,
      );
      final result = await DocumentConverterService.pdfToTxt(pdfFile.path);
      expect(result.outputPath.toLowerCase().endsWith('.txt'), isTrue);
      final body = await File(result.outputPath).readAsString();
      expect(body.isNotEmpty, isTrue);
    });

    test('PDF → DOCX', () async {
      final named = await ConverterFixtures.writePdf(
        tmp,
        name: 'letter.pdf',
        text: 'ScanMe PDF to DOCX probe',
      );
      final result = await DocumentConverterService.pdfToDocx(named.path);
      expect(result.outputPath.toLowerCase().endsWith('.docx'), isTrue);
      expect(result.label, '.docx');
      final bytes = await File(result.outputPath).readAsBytes();
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4b);
    });

    test('DOCX → PDF · multi paragraph', () async {
      final src = await ConverterFixtures.writeDocx(tmp);
      final result = await DocumentConverterService.docxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
      final bytes = await File(result.outputPath).readAsBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('DOCX → PDF · single paragraph', () async {
      final src = await ConverterFixtures.writeDocx(
        tmp,
        name: 'one.docx',
        paragraphs: const ['Only one block'],
      );
      final result = await DocumentConverterService.docxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('PPTX → PDF · one slide', () async {
      final src = await ConverterFixtures.writePptx(tmp);
      final result = await DocumentConverterService.pptxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
      expect(result.label, 'PDF');
    });

    test('PPTX → PDF · two slides', () async {
      final src = await ConverterFixtures.writePptx(
        tmp,
        name: 'multi.pptx',
        slideTexts: const ['Slide alpha', 'Slide beta'],
      );
      final result = await DocumentConverterService.pptxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
      expect(await File(result.outputPath).length(), greaterThan(200));
    });

    test('PPTX → PDF · three slides', () async {
      final src = await ConverterFixtures.writePptx(
        tmp,
        name: 'three.pptx',
        slideTexts: const ['A', 'B', 'C'],
      );
      final result = await DocumentConverterService.pptxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
    });

    test('XLSX → CSV · basic', () async {
      final src = await ConverterFixtures.writeXlsx(tmp);
      final result = await DocumentConverterService.xlsxToCsv(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.csv'), isTrue);
      expect(result.mimeType, 'text/csv');
      final body = await File(result.outputPath).readAsString();
      expect(body, contains('Name'));
      expect(body, contains('ScanMe'));
    });

    test('XLSX → CSV · commas escaped', () async {
      final src = await ConverterFixtures.writeXlsx(
        tmp,
        name: 'commas.xlsx',
        rows: const [
          ['City', 'Note'],
          ['Dhaka', 'Hello, world'],
        ],
      );
      final result = await DocumentConverterService.xlsxToCsv(src.path);
      final body = await File(result.outputPath).readAsString();
      expect(body, contains('"Hello, world"'));
    });

    test('XLSX → PDF', () async {
      final src = await ConverterFixtures.writeXlsx(tmp, name: 'table.xlsx');
      final result = await DocumentConverterService.xlsxToPdf(src.path);
      expect(result.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
      expect(result.label, 'PDF');
    });
  });

  group('images · full source × target matrix', () {
    const sources = ['png', 'jpg', 'webp', 'gif'];
    final targets = <String, ({_ImgConv call, String ext, String label})>{
      'JPG': (
        call: DocumentConverterService.imageToJpeg,
        ext: 'jpg',
        label: 'JPEG',
      ),
      'PNG': (
        call: DocumentConverterService.imageToPng,
        ext: 'png',
        label: 'PNG',
      ),
      'WebP': (
        call: DocumentConverterService.imageToWebp,
        ext: 'webp',
        label: 'WebP',
      ),
      'GIF': (
        call: DocumentConverterService.imageToGif,
        ext: 'gif',
        label: 'GIF',
      ),
    };

    for (final srcExt in sources) {
      for (final entry in targets.entries) {
        test('${srcExt.toUpperCase()} → ${entry.key}', () async {
          final src = await srcImage(srcExt);
          final result = await entry.value.call(src.path);
          await expectImageOut(
            result,
            ext: entry.value.ext,
            label: entry.value.label,
          );
        });
      }
    }

    test('decodeAnyImage · all raster types', () async {
      for (final ext in sources) {
        final f = await srcImage(ext);
        final decoded = await DocumentConverterService.decodeAnyImage(f.path);
        expect(decoded.width, greaterThan(0), reason: ext);
      }
    });

    test('heicToJpeg · JPEG bytes with .heic name (decode-by-content)', () async {
      // Native HEIC decode needs platform; JPEG content still decodes via image package.
      final f = await ConverterFixtures.writeImage(
        tmp,
        'photo.heic',
        ConverterFixtures.jpgBytes(),
      );
      final result = await DocumentConverterService.heicToJpeg(f.path);
      await expectImageOut(result, ext: 'jpg', label: 'JPEG');
    });

    test(
      'heicToJpeg · real HEIC bitstream',
      () async {},
      skip: 'needs platform HEIC codec (ImageCodecBridge) + real .heic fixture',
    );
  });
}
