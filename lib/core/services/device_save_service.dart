import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Save generated files through the **system file manager**
/// (`FilePicker.saveFile` → Android `ACTION_CREATE_DOCUMENT` / iOS export).
///
/// User picks folder + name. Cancel returns `null` (not an error).
abstract final class DeviceSaveService {
  DeviceSaveService._();

  /// Prompt the user to create/save a file. Returns saved path/URI, or `null`
  /// if they cancelled the system dialog.
  static Future<String?> saveFile({
    required String sourcePath,
    String? displayName,
    String? dialogTitle,
  }) async {
    final src = File(sourcePath);
    if (!await src.exists()) {
      throw StateError('File not found: $sourcePath');
    }
    final name = _safeName(displayName ?? p.basename(sourcePath));
    final bytes = await src.readAsBytes();
    return saveBytes(
      bytes: bytes,
      fileName: name,
      dialogTitle: dialogTitle,
    );
  }

  /// Same as [saveFile] but from in-memory bytes.
  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    String? dialogTitle,
  }) async {
    final safe = _safeName(fileName);
    final ext = p.extension(safe).replaceFirst('.', '').toLowerCase();
    final extensions = ext.isEmpty ? null : <String>[ext];

    try {
      final result = await FilePicker.saveFile(
        dialogTitle: dialogTitle ?? 'Save to your phone',
        fileName: safe,
        bytes: bytes,
        type: extensions == null ? FileType.any : FileType.custom,
        allowedExtensions: extensions,
      );
      if (result == null || result.isEmpty) {
        return null; // user cancelled
      }
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DeviceSaveService.saveFile failed: $e\n$st');
      }
      rethrow;
    }
  }

  /// Save many files; each opens its own system “Save as” dialog.
  /// Skips cancelled ones. Returns only successful paths.
  static Future<List<String>> saveFiles(List<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      final where = await saveFile(sourcePath: path);
      if (where != null) out.add(where);
    }
    return out;
  }

  static String _safeName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return cleaned.isEmpty ? 'scanme_file' : cleaned;
  }

  static String mimeFor(String name) {
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.pdf' => 'application/pdf',
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.txt' => 'text/plain',
      '.pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
  }
}
