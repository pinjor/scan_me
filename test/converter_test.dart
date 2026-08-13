import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
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
  });
}
