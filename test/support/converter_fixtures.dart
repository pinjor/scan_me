import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fake documents path for converter unit tests.
class FakePathProvider extends PathProviderPlatform {
  FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Offline fixture builders — no network.
abstract final class ConverterFixtures {
  ConverterFixtures._();

  static Future<File> writePdf(
    Directory dir, {
    String name = 'probe.pdf',
    String text = 'ScanMe PDF probe',
    int pages = 1,
  }) async {
    final pdf = pw.Document();
    for (var i = 0; i < pages; i++) {
      final label = pages == 1 ? text : '$text · page ${i + 1}';
      pdf.addPage(
        pw.Page(build: (c) => pw.Text(label)),
      );
    }
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<File> writeTxt(
    Directory dir, {
    String name = 'notes.txt',
    String body = 'Hello ScanMe\n\nSecond paragraph.',
  }) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsString(body, encoding: utf8);
    return file;
  }

  static img.Image solidImage({
    int width = 40,
    int height = 30,
    int r = 10,
    int g = 120,
    int b = 200,
  }) {
    final im = img.Image(width: width, height: height, numChannels: 3);
    img.fill(im, color: img.ColorRgb8(r, g, b));
    return im;
  }

  static Uint8List pngBytes({int width = 40, int height = 30}) =>
      Uint8List.fromList(
        img.encodePng(solidImage(width: width, height: height)),
      );

  static Uint8List jpgBytes({
    int width = 40,
    int height = 30,
    int quality = 90,
  }) =>
      Uint8List.fromList(
        img.encodeJpg(
          solidImage(width: width, height: height, r: 200, g: 40, b: 40),
          quality: quality,
        ),
      );

  static Uint8List webpBytes({int width = 40, int height = 30}) =>
      Uint8List.fromList(
        img.encodeWebP(
          solidImage(width: width, height: height, r: 40, g: 180, b: 90),
        ),
      );

  static Uint8List gifBytes({int width = 40, int height = 30}) =>
      Uint8List.fromList(
        img.encodeGif(
          solidImage(width: width, height: height, r: 180, g: 80, b: 200),
        ),
      );

  static Future<File> writeImage(
    Directory dir,
    String name,
    Uint8List bytes,
  ) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> writeDocx(
    Directory dir, {
    String name = 'letter.docx',
    List<String> paragraphs = const ['ScanMe DOCX probe', 'Second line'],
  }) async {
    final body = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">',
      )
      ..writeln('<w:body>');
    for (final para in paragraphs) {
      body.writeln(
        '<w:p><w:r><w:t>${_xmlEscape(para)}</w:t></w:r></w:p>',
      );
    }
    body
      ..writeln('</w:body>')
      ..writeln('</w:document>');

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(ArchiveFile.string('word/document.xml', body.toString()));

    return _writeZip(dir, name, archive);
  }

  static Future<File> writePptx(
    Directory dir, {
    String name = 'deck.pptx',
    List<String> slideTexts = const ['ScanMe PPTX slide 1'],
  }) async {
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
${[
            for (var i = 1; i <= slideTexts.length; i++)
              '  <Override PartName="/ppt/slides/slide$i.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
          ].join('\n')}
</Types>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'ppt/presentation.xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldIdLst>
${[
            for (var i = 1; i <= slideTexts.length; i++)
              '    <p:sldId id="${255 + i}" r:id="rId$i"/>',
          ].join('\n')}
  </p:sldIdLst>
</p:presentation>''',
        ),
      );

    for (var i = 0; i < slideTexts.length; i++) {
      final n = i + 1;
      final text = slideTexts[i];
      archive.addFile(
        ArchiveFile.string(
          'ppt/slides/slide$n.xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:bodyPr/>
          <a:p><a:r><a:t>${_xmlEscape(text)}</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''',
        ),
      );
    }

    return _writeZip(dir, name, archive);
  }

  /// First row = headers. Remaining rows = data. Uses shared strings.
  static Future<File> writeXlsx(
    Directory dir, {
    String name = 'sheet.xlsx',
    List<List<String>> rows = const [
      ['Name', 'Qty'],
      ['ScanMe', '2'],
      ['Probe', '5'],
    ],
  }) async {
    final shared = <String>[];
    int si(String s) {
      final i = shared.indexOf(s);
      if (i >= 0) return i;
      shared.add(s);
      return shared.length - 1;
    }

    for (final row in rows) {
      for (final cell in row) {
        si(cell);
      }
    }

    final ss = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${shared.length}" uniqueCount="${shared.length}">',
      );
    for (final s in shared) {
      ss.writeln('<si><t>${_xmlEscape(s)}</t></si>');
    }
    ss.writeln('</sst>');

    final sheet = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
      )
      ..writeln('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      sheet.writeln('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final col = _colName(c);
        final idx = si(rows[r][c]);
        sheet.writeln(
          '<c r="$col${r + 1}" t="s"><v>$idx</v></c>',
        );
      }
      sheet.writeln('</row>');
    }
    sheet
      ..writeln('</sheetData>')
      ..writeln('</worksheet>');

    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          '[Content_Types].xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          '_rels/.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/workbook.xml',
          '''<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''',
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          '''<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>''',
        ),
      )
      ..addFile(ArchiveFile.string('xl/sharedStrings.xml', ss.toString()))
      ..addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet.toString()));

    return _writeZip(dir, name, archive);
  }

  static Future<File> _writeZip(
    Directory dir,
    String name,
    Archive archive,
  ) async {
    final encoded = ZipEncoder().encodeBytes(archive);
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(encoded);
    return file;
  }

  static String _colName(int index) {
    var n = index;
    final buf = StringBuffer();
    do {
      buf.write(String.fromCharCode(65 + (n % 26)));
      n = n ~/ 26 - 1;
    } while (n >= 0);
    return buf.toString().split('').reversed.join();
  }

  static String _xmlEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
