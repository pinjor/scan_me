import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:scanme/features/converters/image_tools_service.dart';

import 'support/converter_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('scanme_imgtools_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> writeSrc(String ext, {int w = 200, int h = 100}) async {
    final bytes = switch (ext) {
      'png' => ConverterFixtures.pngBytes(width: w, height: h),
      'jpg' => ConverterFixtures.jpgBytes(width: w, height: h),
      'webp' => ConverterFixtures.webpBytes(width: w, height: h),
      'gif' => ConverterFixtures.gifBytes(width: w, height: h),
      _ => throw ArgumentError(ext),
    };
    return ConverterFixtures.writeImage(tmp, 'src_$w${h}_$ext.$ext', bytes);
  }

  group('probe', () {
    for (final ext in ['png', 'jpg', 'webp', 'gif']) {
      test('dims · $ext', () async {
        final src = await writeSrc(ext, w: 80, h: 60);
        final probe = await ImageToolsService.probe(src.path);
        expect(probe.width, 80);
        expect(probe.height, 60);
        expect(probe.bytes, greaterThan(0));
      });
    }
  });

  group('resizePixels · long edge × formats', () {
    for (final format in ['jpg', 'png', 'webp', 'gif']) {
      test('long edge → $format', () async {
        final src = await writeSrc('png', w: 400, h: 200);
        final result = await ImageToolsService.resizePixels(
          imagePath: src.path,
          maxLongEdge: 100,
          format: format,
        );
        expect(result.outputPath.toLowerCase().endsWith('.$format'), isTrue);
        final out =
            img.decodeImage(await File(result.outputPath).readAsBytes())!;
        expect(out.width, 100);
        expect(out.height, 50);
      });
    }
  });

  group('resizePixels · exact × source types', () {
    for (final srcExt in ['png', 'jpg', 'webp', 'gif']) {
      test('exact from $srcExt', () async {
        final src = await writeSrc(srcExt, w: 120, h: 80);
        final result = await ImageToolsService.resizePixels(
          imagePath: src.path,
          width: 64,
          height: 32,
          format: 'png',
        );
        final out =
            img.decodeImage(await File(result.outputPath).readAsBytes())!;
        expect(out.width, 64);
        expect(out.height, 32);
      });
    }

    test('long edge no-op when already smaller', () async {
      final src = await writeSrc('png', w: 50, h: 40);
      final result = await ImageToolsService.resizePixels(
        imagePath: src.path,
        maxLongEdge: 200,
        format: 'jpg',
      );
      final out = img.decodeImage(await File(result.outputPath).readAsBytes())!;
      expect(out.width, 50);
      expect(out.height, 40);
    });
  });

  group('compressToSize', () {
    test('large JPG under target', () async {
      final big = ConverterFixtures.solidImage(width: 800, height: 600);
      for (var y = 0; y < big.height; y += 7) {
        for (var x = 0; x < big.width; x += 11) {
          big.setPixelRgb(x, y, (x * 3) % 255, (y * 5) % 255, 120);
        }
      }
      final src = await ConverterFixtures.writeImage(
        tmp,
        'big.jpg',
        Uint8List.fromList(img.encodeJpg(big, quality: 95)),
      );
      const target = 80 * 1024;
      final result = await ImageToolsService.compressToSize(
        imagePath: src.path,
        targetBytes: target,
      );
      expect(result.outputPath.toLowerCase().endsWith('.jpg'), isTrue);
      expect(await File(result.outputPath).length(), lessThanOrEqualTo(target));
    });

    for (final srcExt in ['png', 'webp', 'gif']) {
      test('from $srcExt', () async {
        final src = await writeSrc(srcExt, w: 400, h: 300);
        final result = await ImageToolsService.compressToSize(
          imagePath: src.path,
          targetBytes: 150 * 1024,
        );
        expect(result.label, 'JPEG');
        expect(result.outputPath.toLowerCase().endsWith('.jpg'), isTrue);
      });
    }
  });

  group('convertImage · source × format × quality', () {
    const sources = ['png', 'jpg', 'webp', 'gif'];
    const formats = ['jpg', 'png', 'webp', 'gif'];
    const qualities = [95, 85, 70];

    for (final srcExt in sources) {
      for (final format in formats) {
        test('$srcExt → $format', () async {
          final src = await writeSrc(srcExt, w: 60, h: 40);
          final result = await ImageToolsService.convertImage(
            imagePath: src.path,
            format: format,
            quality: 85,
          );
          expect(result.outputPath.toLowerCase().endsWith('.$format'), isTrue);
          final decoded =
              img.decodeImage(await File(result.outputPath).readAsBytes());
          expect(decoded, isNotNull, reason: '$srcExt → $format');
        });
      }
    }

    for (final q in qualities) {
      test('jpg quality $q', () async {
        final src = await writeSrc('png');
        final result = await ImageToolsService.convertImage(
          imagePath: src.path,
          format: 'jpg',
          quality: q,
        );
        expect(result.label, 'JPEG');
        expect(File(result.outputPath).existsSync(), isTrue);
      });
    }

    test('convertImage with maxLongEdge', () async {
      final src = await writeSrc('png', w: 300, h: 150);
      final result = await ImageToolsService.convertImage(
        imagePath: src.path,
        format: 'jpg',
        maxLongEdge: 100,
        quality: 90,
      );
      final out = img.decodeImage(await File(result.outputPath).readAsBytes())!;
      expect(out.width, 100);
      expect(out.height, 50);
    });
  });

  group('saveCroppedBytes · formats', () {
    for (final format in ['jpg', 'png', 'webp', 'gif']) {
      test('crop → $format', () async {
        final src = await writeSrc('png', w: 60, h: 40);
        final crop = format == 'png' || format == 'gif'
            ? ConverterFixtures.pngBytes(width: 30, height: 20)
            : ConverterFixtures.jpgBytes(width: 30, height: 20);
        final result = await ImageToolsService.saveCroppedBytes(
          sourcePath: src.path,
          croppedBytes: crop,
          format: format,
        );
        expect(result.outputPath.toLowerCase().endsWith('.$format'), isTrue);
        final out =
            img.decodeImage(await File(result.outputPath).readAsBytes())!;
        expect(out.width, 30);
        expect(out.height, 20);
      });
    }
  });

  group('pipeline combos', () {
    test('resize → convert', () async {
      final src = await writeSrc('png', w: 300, h: 150);
      final resized = await ImageToolsService.resizePixels(
        imagePath: src.path,
        maxLongEdge: 120,
        format: 'jpg',
      );
      final converted = await ImageToolsService.convertImage(
        imagePath: resized.outputPath,
        format: 'png',
      );
      final out =
          img.decodeImage(await File(converted.outputPath).readAsBytes())!;
      expect(out.width, 120);
      expect(out.height, 60);
    });

    test('resize → compress', () async {
      final src = await writeSrc('jpg', w: 500, h: 400);
      final resized = await ImageToolsService.resizePixels(
        imagePath: src.path,
        maxLongEdge: 300,
        format: 'jpg',
      );
      final compressed = await ImageToolsService.compressToSize(
        imagePath: resized.outputPath,
        targetBytes: 200 * 1024,
      );
      expect(compressed.outputPath.toLowerCase().endsWith('.jpg'), isTrue);
    });

    test('crop → resize', () async {
      final src = await writeSrc('png');
      final crop = await ImageToolsService.saveCroppedBytes(
        sourcePath: src.path,
        croppedBytes: ConverterFixtures.jpgBytes(width: 80, height: 80),
        format: 'jpg',
      );
      final resized = await ImageToolsService.resizePixels(
        imagePath: crop.outputPath,
        width: 40,
        height: 40,
        format: 'png',
      );
      final out =
          img.decodeImage(await File(resized.outputPath).readAsBytes())!;
      expect(out.width, 40);
      expect(out.height, 40);
    });
  });

  group('friendlySize / suggestName', () {
    test('friendlySize labels', () {
      expect(ImageToolsService.friendlySize(500), '500 B');
      expect(ImageToolsService.friendlySize(2048), contains('KB'));
      expect(ImageToolsService.friendlySize(2 * 1024 * 1024), contains('MB'));
    });

    test('suggestName cleans', () {
      expect(
        ImageToolsService.suggestName('open_with_Photo.PNG'),
        'Photo',
      );
      expect(p.basename(ImageToolsService.suggestName('/tmp/x.jpg')), 'x');
    });
  });
}
