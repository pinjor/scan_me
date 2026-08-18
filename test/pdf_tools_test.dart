import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:scanme/features/pdf_tools/pdf_tools_exception.dart';
import 'package:scanme/features/pdf_tools/pdf_tools_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'support/converter_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scanme_pdf_tools_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<int> pagesOf(String path) async {
    final bytes = await File(path).readAsBytes();
    final doc = sf.PdfDocument(inputBytes: bytes);
    try {
      return doc.pages.count;
    } finally {
      doc.dispose();
    }
  }

  Future<void> expectPdfMagic(String path) async {
    final bytes = await File(path).readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  }

  test('pageCount', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 3);
    expect(await PdfToolsService.pageCount(pdf.path), 3);
  });

  test('merge two PDFs preserves page counts', () async {
    final a = await ConverterFixtures.writePdf(tmp, name: 'a.pdf', pages: 2);
    final b = await ConverterFixtures.writePdf(tmp, name: 'b.pdf', pages: 3);
    final r = await PdfToolsService.merge(paths: [a.path, b.path]);
    await expectPdfMagic(r.outputPath);
    expect(await pagesOf(r.outputPath), 5);
    expect(await File(a.path).exists(), isTrue);
  });

  test('merge rejects a single file', () async {
    final a = await ConverterFixtures.writePdf(tmp);
    expect(
      () => PdfToolsService.merge(paths: [a.path]),
      throwsA(isA<PdfToolsException>()),
    );
  });

  test('extract pages keeps only selected', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 4);
    final r = await PdfToolsService.extractPages(
      path: pdf.path,
      indexes: [0, 2],
    );
    expect(await pagesOf(r.outputPath), 2);
    expect(await File(pdf.path).exists(), isTrue);
  });

  test('delete pages keeps remaining', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 4);
    final r = await PdfToolsService.deletePages(
      path: pdf.path,
      indexes: {1, 3},
    );
    expect(await pagesOf(r.outputPath), 2);
  });

  test('delete refuses to drop every page', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 2);
    expect(
      () => PdfToolsService.deletePages(path: pdf.path, indexes: {0, 1}),
      throwsA(isA<PdfToolsException>()),
    );
  });

  test('reorder pages matches order length', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 3);
    final r = await PdfToolsService.reorderPages(
      path: pdf.path,
      order: const [2, 0, 1],
    );
    expect(await pagesOf(r.outputPath), 3);
  });

  test('rotate all pages writes a new file', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 2);
    final r = await PdfToolsService.rotatePages(
      path: pdf.path,
      indexes: {},
      degrees: 90,
    );
    await expectPdfMagic(r.outputPath);
    expect(await pagesOf(r.outputPath), 2);
    expect(p.basename(r.outputPath), isNot(p.basename(pdf.path)));
  });

  test('split ranges yields one PDF per range', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 5);
    final out = await PdfToolsService.splitRanges(
      path: pdf.path,
      ranges: const [PdfRange(0, 1), PdfRange(2, 4)],
    );
    expect(out, hasLength(2));
    expect(await pagesOf(out[0].outputPath), 2);
    expect(await pagesOf(out[1].outputPath), 3);
  });

  test('split every page', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 3);
    final out = await PdfToolsService.splitEveryPage(path: pdf.path);
    expect(out, hasLength(3));
    for (final r in out) {
      expect(await pagesOf(r.outputPath), 1);
    }
  });

  test('compress native does not grow file and keeps page count', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 2);
    final original = await File(pdf.path).length();
    final outcome = await PdfToolsService.compress(
      path: pdf.path,
      preset: PdfCompressPreset.balanced,
      allowRaster: false,
    );
    expect(await pagesOf(outcome.result.outputPath), 2);
    expect(outcome.newBytes, lessThanOrEqualTo(original));
  });

  test('images to PDF', () async {
    final img = File(p.join(tmp.path, 'p.png'));
    await img.writeAsBytes(ConverterFixtures.pngBytes());
    final r = await PdfToolsService.imagesToPdf(imagePaths: [img.path]);
    await expectPdfMagic(r.outputPath);
    expect(await pagesOf(r.outputPath), 1);
  });

  test('invalid bytes → friendly error', () async {
    final junk = File(p.join(tmp.path, 'nope.pdf'));
    await junk.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5, 6]));
    expect(
      () => PdfToolsService.pageCount(junk.path),
      throwsA(
        isA<PdfToolsException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('valid pdf'),
        ),
      ),
    );
  });

  test('merge three PDFs 3+5+2 = 10 and originals stay', () async {
    final a = await ConverterFixtures.writePdf(tmp, name: 'A.pdf', pages: 3);
    final b = await ConverterFixtures.writePdf(tmp, name: 'B.pdf', pages: 5);
    final c = await ConverterFixtures.writePdf(tmp, name: 'C.pdf', pages: 2);
    final r = await PdfToolsService.merge(paths: [a.path, b.path, c.path]);
    await expectPdfMagic(r.outputPath);
    expect(await pagesOf(r.outputPath), 10);
    expect(await File(a.path).exists(), isTrue);
    expect(await File(b.path).exists(), isTrue);
    expect(await File(c.path).exists(), isTrue);
  });

  test('delete empty selection is rejected', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 4);
    expect(
      () => PdfToolsService.deletePages(path: pdf.path, indexes: {}),
      throwsA(
        isA<PdfToolsException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('select'),
        ),
      ),
    );
  });

  test('split every page on a 1-page PDF is rejected with split copy', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 1);
    expect(
      () => PdfToolsService.splitEveryPage(path: pdf.path),
      throwsA(
        isA<PdfToolsException>().having(
          (e) => e.message.toLowerCase(),
          'message',
          contains('split'),
        ),
      ),
    );
  });

  test('extract 2,5,8 from 8-page PDF keeps three pages', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 8);
    final r = await PdfToolsService.extractPages(
      path: pdf.path,
      indexes: const [1, 4, 7],
    );
    expect(await pagesOf(r.outputPath), 3);
    expect(await File(pdf.path).exists(), isTrue);
  });

  test('reorder 3 5 1 4 2 keeps five pages', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 5);
    final r = await PdfToolsService.reorderPages(
      path: pdf.path,
      order: const [2, 4, 0, 3, 1],
    );
    expect(await pagesOf(r.outputPath), 5);
  });

  test('split 12-page PDF into 1-4 / 5-8 / 9-12', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 12);
    final out = await PdfToolsService.splitRanges(
      path: pdf.path,
      ranges: const [PdfRange(0, 3), PdfRange(4, 7), PdfRange(8, 11)],
    );
    expect(out, hasLength(3));
    expect(await pagesOf(out[0].outputPath), 4);
    expect(await pagesOf(out[1].outputPath), 4);
    expect(await pagesOf(out[2].outputPath), 4);
  });

  test('extract after rotate still writes a valid PDF', () async {
    final pdf = await ConverterFixtures.writePdf(tmp, pages: 1);
    final rotated = await PdfToolsService.rotatePages(
      path: pdf.path,
      indexes: {0},
      degrees: 90,
    );
    final extracted = await PdfToolsService.extractPages(
      path: rotated.outputPath,
      indexes: const [0],
    );
    await expectPdfMagic(extracted.outputPath);
    expect(await pagesOf(extracted.outputPath), 1);
    expect(await File(pdf.path).exists(), isTrue);
  });
}
