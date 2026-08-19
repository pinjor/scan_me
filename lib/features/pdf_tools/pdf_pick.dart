import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/access_permission.dart';
import '../converters/document_converter_service.dart';

Future<String?> pickSinglePdf(BuildContext context) async {
  if (!await AccessPermission.ensureFiles(context)) return null;
  if (!context.mounted) return null;
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
    dialogTitle: 'Select PDF',
  );
  if (file == null) return null;
  return _materialize(file);
}

Future<List<String>> pickManyPdfs(BuildContext context) async {
  if (!await AccessPermission.ensureFiles(context)) return const [];
  if (!context.mounted) return const [];
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
