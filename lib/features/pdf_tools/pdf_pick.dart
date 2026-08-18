import 'package:file_picker/file_picker.dart';

import '../converters/document_converter_service.dart';

Future<String?> pickSinglePdf() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    dialogTitle: 'Select PDF',
  );
  if (file == null) return null;
  return _materialize(file);
}

Future<List<String>> pickManyPdfs() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    dialogTitle: 'Select PDFs',
  );
  if (files.isEmpty) return const [];
  final out = <String>[];
  for (final f in files) {
    final path = await _materialize(f);
    if (path != null) out.add(path);
  }
  return out;
}

Future<String?> _materialize(PlatformFile file) async {
  var path = file.path;
  if (path != null && path.isNotEmpty) return path;
  try {
    final bytes = await file.readAsBytes();
    return await DocumentConverterService.materializePath(
      preferredName: file.name,
      bytes: bytes,
    );
  } catch (_) {
    return null;
  }
}
