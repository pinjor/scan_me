import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:scanme/features/converters/convert_catalog.dart';
import 'package:scanme/features/converters/document_converter_service.dart';
import 'package:scanme/features/converters/intent_convert_screen.dart';

import 'support/converter_fixtures.dart';

/// Every convert tool (documents + images) through production dispatchers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scanme_all_conv_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> expectPdf(ConvertResult r) async {
    expect(r.outputPath.toLowerCase().endsWith('.pdf'), isTrue);
    final bytes = await File(r.outputPath).readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  }

  Future<void> expectExt(ConvertResult r, String ext) async {
    expect(File(r.outputPath).existsSync(), isTrue);
    expect(r.outputPath.toLowerCase().endsWith('.$ext'), isTrue);
  }

  group('runSimpleConvert · every document tool', () {
    test('pdfToTxt', () async {
      final src = await ConverterFixtures.writePdf(tmp, name: 'a.pdf');
      final r = await runSimpleConvert(ConvertToolId.pdfToTxt, src.path);
      await expectExt(r, 'txt');
      expect(r.label, '.txt');
      expect((await File(r.outputPath).readAsString()).isNotEmpty, isTrue);
    });

    test('pdfToTxt · 5 pages', () async {
      final src = await ConverterFixtures.writePdf(
        tmp,
        name: 'five.pdf',
        text: 'Page body',
        pages: 5,
      );
      final r = await runSimpleConvert(ConvertToolId.pdfToTxt, src.path);
      await expectExt(r, 'txt');
    });

    test('pdfToDocx', () async {
      final src = await ConverterFixtures.writePdf(tmp, name: 'b.pdf');
      final r = await runSimpleConvert(ConvertToolId.pdfToDocx, src.path);
      await expectExt(r, 'docx');
      final bytes = await File(r.outputPath).readAsBytes();
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4b);
    });

    test('pdfToDocx · multi page', () async {
      final src = await ConverterFixtures.writePdf(
        tmp,
        name: 'c.pdf',
        pages: 3,
      );
      final r = await runSimpleConvert(ConvertToolId.pdfToDocx, src.path);
      await expectExt(r, 'docx');
    });

    test('txtToPdf', () async {
      final src = await ConverterFixtures.writeTxt(tmp);
      final r = await runSimpleConvert(ConvertToolId.txtToPdf, src.path);
      await expectPdf(r);
    });

    test('txtToPdf · empty-ish whitespace', () async {
      final src = await ConverterFixtures.writeTxt(
        tmp,
        name: 'blank.txt',
        body: '   \n\n  x  \n',
      );
      final r = await runSimpleConvert(ConvertToolId.txtToPdf, src.path);
      await expectPdf(r);
    });

    test('txtToPdf · md extension name', () async {
      final src = await ConverterFixtures.writeTxt(
        tmp,
        name: 'readme.md',
        body: '# Title\n\nBody',
      );
      final r = await runSimpleConvert(ConvertToolId.txtToPdf, src.path);
      await expectPdf(r);
    });

    test('pptxToPdf · 1 slide', () async {
      final src = await ConverterFixtures.writePptx(tmp);
      final r = await runSimpleConvert(ConvertToolId.pptxToPdf, src.path);
      await expectPdf(r);
    });

    test('pptxToPdf · 4 slides', () async {
      final src = await ConverterFixtures.writePptx(
        tmp,
        name: 'deck4.pptx',
        slideTexts: const ['One', 'Two', 'Three', 'Four'],
      );
      final r = await runSimpleConvert(ConvertToolId.pptxToPdf, src.path);
      await expectPdf(r);
    });

    test('docxToPdf', () async {
      final src = await ConverterFixtures.writeDocx(tmp);
      final r = await runSimpleConvert(ConvertToolId.docxToPdf, src.path);
      await expectPdf(r);
    });

    test('docxToPdf · many paragraphs', () async {
      final src = await ConverterFixtures.writeDocx(
        tmp,
        name: 'long.docx',
        paragraphs: List.generate(25, (i) => 'Paragraph $i of ScanMe doc'),
      );
      final r = await runSimpleConvert(ConvertToolId.docxToPdf, src.path);
      await expectPdf(r);
    });

    test('xlsxToCsv', () async {
      final src = await ConverterFixtures.writeXlsx(tmp);
      final r = await runSimpleConvert(ConvertToolId.xlsxToCsv, src.path);
      await expectExt(r, 'csv');
      expect(r.mimeType, 'text/csv');
      final body = await File(r.outputPath).readAsString();
      expect(body, contains('ScanMe'));
    });

    test('xlsxToCsv · wide sheet', () async {
      final src = await ConverterFixtures.writeXlsx(
        tmp,
        name: 'wide.xlsx',
        rows: [
          ['A', 'B', 'C', 'D', 'E'],
          ['1', '2', '3', '4', '5'],
          ['x', 'y', 'z', 'w', 'v'],
        ],
      );
      final r = await runSimpleConvert(ConvertToolId.xlsxToCsv, src.path);
      final body = await File(r.outputPath).readAsString();
      expect(body.split('\n').where((l) => l.trim().isNotEmpty).length, 3);
    });

    test('xlsxToPdf', () async {
      final src = await ConverterFixtures.writeXlsx(tmp, name: 't.xlsx');
      final r = await runSimpleConvert(ConvertToolId.xlsxToPdf, src.path);
      await expectPdf(r);
    });

    test('xlsxToPdf · header-only + one data row', () async {
      final src = await ConverterFixtures.writeXlsx(
        tmp,
        name: 'tiny.xlsx',
        rows: const [
          ['Col'],
          ['Val'],
        ],
      );
      final r = await runSimpleConvert(ConvertToolId.xlsxToPdf, src.path);
      await expectPdf(r);
    });
  });

  group('runSimpleConvert · every image format tool', () {
    const tools = <(ConvertToolId, String, String)>[
      (ConvertToolId.toJpg, 'jpg', 'JPEG'),
      (ConvertToolId.toPng, 'png', 'PNG'),
      (ConvertToolId.toWebp, 'webp', 'WebP'),
      (ConvertToolId.toGif, 'gif', 'GIF'),
    ];
    const sources = ['png', 'jpg', 'webp', 'gif'];

    for (final tool in tools) {
      for (final srcExt in sources) {
        test('${tool.$1.name} from .$srcExt', () async {
          final bytes = switch (srcExt) {
            'png' => ConverterFixtures.pngBytes(),
            'jpg' => ConverterFixtures.jpgBytes(),
            'webp' => ConverterFixtures.webpBytes(),
            'gif' => ConverterFixtures.gifBytes(),
            _ => throw StateError(srcExt),
          };
          final src = await ConverterFixtures.writeImage(
            tmp,
            'in.$srcExt',
            bytes,
          );
          final r = await runSimpleConvert(tool.$1, src.path);
          await expectExt(r, tool.$2);
          expect(r.label, tool.$3);
          expect(
            img.decodeImage(await File(r.outputPath).readAsBytes()),
            isNotNull,
          );
        });
      }
    }

    test('heicToJpg · JPEG content named .heic', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'cam.heic',
        ConverterFixtures.jpgBytes(),
      );
      final r = await runSimpleConvert(ConvertToolId.heicToJpg, src.path);
      await expectExt(r, 'jpg');
    });
  });

  group('runSimpleConvert · hub tools throw', () {
    for (final id in [
      ConvertToolId.imageFormats,
      ConvertToolId.editImages,
      ConvertToolId.crop,
      ConvertToolId.resize,
      ConvertToolId.compress,
    ]) {
      test('$id unsupported', () async {
        final src = await ConverterFixtures.writeImage(
          tmp,
          'x.png',
          ConverterFixtures.pngBytes(),
        );
        expect(
          () => runSimpleConvert(id, src.path),
          throwsA(isA<UnsupportedError>()),
        );
      });
    }
  });

  group('IntentConvertKind.run · every kind', () {
    test('pdfToTxt', () async {
      final src = await ConverterFixtures.writePdf(tmp);
      final r = await IntentConvertKind.pdfToTxt.run(src.path);
      await expectExt(r, 'txt');
    });

    test('pdfToDocx', () async {
      final src = await ConverterFixtures.writePdf(tmp);
      final r = await IntentConvertKind.pdfToDocx.run(src.path);
      await expectExt(r, 'docx');
    });

    test('txtToPdf', () async {
      final src = await ConverterFixtures.writeTxt(tmp);
      final r = await IntentConvertKind.txtToPdf.run(src.path);
      await expectPdf(r);
    });

    test('pptxToPdf', () async {
      final src = await ConverterFixtures.writePptx(tmp);
      final r = await IntentConvertKind.pptxToPdf.run(src.path);
      await expectPdf(r);
    });

    test('docxToPdf', () async {
      final src = await ConverterFixtures.writeDocx(tmp);
      final r = await IntentConvertKind.docxToPdf.run(src.path);
      await expectPdf(r);
    });

    test('xlsxToCsv', () async {
      final src = await ConverterFixtures.writeXlsx(tmp);
      final r = await IntentConvertKind.xlsxToCsv.run(src.path);
      await expectExt(r, 'csv');
    });

    test('xlsxToPdf', () async {
      final src = await ConverterFixtures.writeXlsx(tmp);
      final r = await IntentConvertKind.xlsxToPdf.run(src.path);
      await expectPdf(r);
    });

    test('pngToJpg', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.png',
        ConverterFixtures.pngBytes(),
      );
      final r = await IntentConvertKind.pngToJpg.run(src.path);
      await expectExt(r, 'jpg');
    });

    test('jpgToPng', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.jpg',
        ConverterFixtures.jpgBytes(),
      );
      final r = await IntentConvertKind.jpgToPng.run(src.path);
      await expectExt(r, 'png');
    });

    test('toJpg', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.webp',
        ConverterFixtures.webpBytes(),
      );
      final r = await IntentConvertKind.toJpg.run(src.path);
      await expectExt(r, 'jpg');
    });

    test('toPng', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.gif',
        ConverterFixtures.gifBytes(),
      );
      final r = await IntentConvertKind.toPng.run(src.path);
      await expectExt(r, 'png');
    });

    test('toWebp', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.png',
        ConverterFixtures.pngBytes(),
      );
      final r = await IntentConvertKind.toWebp.run(src.path);
      await expectExt(r, 'webp');
    });

    test('toGif', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.jpg',
        ConverterFixtures.jpgBytes(),
      );
      final r = await IntentConvertKind.toGif.run(src.path);
      await expectExt(r, 'gif');
    });

    test('heicToJpg', () async {
      final src = await ConverterFixtures.writeImage(
        tmp,
        'a.heic',
        ConverterFixtures.jpgBytes(),
      );
      final r = await IntentConvertKind.heicToJpg.run(src.path);
      await expectExt(r, 'jpg');
    });
  });

  group('catalog · every ConvertToolId has meta or is hub', () {
    test('metas resolve', () {
      for (final id in ConvertToolId.values) {
        if (id == ConvertToolId.crop ||
            id == ConvertToolId.resize ||
            id == ConvertToolId.compress) {
          expect(convertToolMeta(id), isNotNull, reason: '$id');
          continue;
        }
        if (id == ConvertToolId.editImages) {
          expect(convertToolMeta(id)?.id, ConvertToolId.imageFormats);
          continue;
        }
        expect(convertToolMeta(id), isNotNull, reason: '$id');
      }
    });

    test('pickHintsFor every id', () {
      for (final id in ConvertToolId.values) {
        final hints = pickHintsFor(id);
        expect(hints.$1, isNotEmpty, reason: '$id');
        expect(hints.$2, isNotEmpty, reason: '$id');
      }
    });
  });

  group('output naming stamps · documents', () {
    test('txtToPdf basename pattern', () async {
      final src = await ConverterFixtures.writeTxt(tmp, name: 'notes.txt');
      final r = await runSimpleConvert(ConvertToolId.txtToPdf, src.path);
      expect(
        RegExp(r'^notes_PDF_\d{4}-\d{2}-\d{2}_\d{4}\.pdf$')
            .hasMatch(p.basename(r.outputPath)),
        isTrue,
      );
    });

    test('pdfToTxt basename pattern', () async {
      final src = await ConverterFixtures.writePdf(tmp, name: 'probe.pdf');
      final r = await runSimpleConvert(ConvertToolId.pdfToTxt, src.path);
      expect(
        RegExp(r'^probe_TXT_\d{4}-\d{2}-\d{2}_\d{4}\.txt$')
            .hasMatch(p.basename(r.outputPath)),
        isTrue,
      );
    });

    test('xlsxToCsv basename pattern', () async {
      final src = await ConverterFixtures.writeXlsx(tmp, name: 'sheet.xlsx');
      final r = await runSimpleConvert(ConvertToolId.xlsxToCsv, src.path);
      expect(
        RegExp(r'^sheet_CSV_\d{4}-\d{2}-\d{2}_\d{4}\.csv$')
            .hasMatch(p.basename(r.outputPath)),
        isTrue,
      );
    });
  });
}
