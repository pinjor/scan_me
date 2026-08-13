import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../shared/models/scanned_document.dart';

/// Local folder layout:
/// `documents/<id>/{originals,processed,thumbnails,export}/` + meta.json
class DocumentStorageService {
  DocumentStorageService();

  static const _uuid = Uuid();
  Directory? _root;

  Future<Directory> get root async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'documents'));
    if (!await _root!.exists()) {
      await _root!.create(recursive: true);
    }
    return _root!;
  }

  Future<Directory> documentDir(String id) async {
    final dir = Directory(p.join((await root).path, id));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> subdir(String id, String name) async {
    final dir = Directory(p.join((await documentDir(id)).path, name));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String newId() => _uuid.v4();

  Future<File> metaFile(String id) async =>
      File(p.join((await documentDir(id)).path, 'meta.json'));

  Future<void> saveDocument(ScannedDocument doc) async {
    final file = await metaFile(doc.id);
    await file.writeAsString(doc.toJsonString());
  }

  Future<ScannedDocument?> loadDocument(String id) async {
    final file = await metaFile(id);
    if (!await file.exists()) return null;
    try {
      return ScannedDocument.fromJsonString(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<List<ScannedDocument>> listDocuments() async {
    final rootDir = await root;
    if (!await rootDir.exists()) return [];
    final docs = <ScannedDocument>[];
    await for (final entity in rootDir.list()) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final doc = await loadDocument(id);
      if (doc != null) docs.add(doc);
    }
    docs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs;
  }

  Future<void> deleteDocument(String id) async {
    final dir = Directory(p.join((await root).path, id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes draft folder only when `meta.json` is missing (never exported).
  Future<void> deleteDraftIfUnsaved(String id) async {
    final meta = File(p.join((await root).path, id, 'meta.json'));
    if (await meta.exists()) return;
    await deleteDocument(id);
  }

  /// Remove orphan dirs left by abandoned scans (no meta.json).
  Future<int> purgeOrphanDrafts() async {
    final rootDir = await root;
    if (!await rootDir.exists()) return 0;
    var removed = 0;
    await for (final entity in rootDir.list()) {
      if (entity is! Directory) continue;
      final meta = File(p.join(entity.path, 'meta.json'));
      if (!await meta.exists()) {
        await entity.delete(recursive: true);
        removed++;
      }
    }
    return removed;
  }

  /// Clears working image folders for retake-all (keeps export/ + meta if any).
  Future<void> clearWorkingFiles(String id) async {
    for (final name in ['originals', 'processed', 'thumbnails']) {
      final dir = Directory(p.join((await documentDir(id)).path, name));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  /// Copy [sourcePath] into originals/ and return destination path.
  Future<String> importOriginal({
    required String documentId,
    required String sourcePath,
    required String pageId,
  }) async {
    final dir = await subdir(documentId, 'originals');
    final dest = p.join(dir.path, '$pageId.jpg');
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<String> writeProcessed({
    required String documentId,
    required String pageId,
    required List<int> bytes,
  }) async {
    final dir = await subdir(documentId, 'processed');
    final dest = p.join(dir.path, '$pageId.jpg');
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<String> writeThumbnail({
    required String documentId,
    required List<int> bytes,
  }) async {
    final dir = await subdir(documentId, 'thumbnails');
    final dest = p.join(dir.path, 'cover.jpg');
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<String> writePdf({
    required String documentId,
    required String name,
    required List<int> bytes,
  }) async {
    final dir = await subdir(documentId, 'export');
    final safe = safeFileName(name);
    final dest = p.join(dir.path, '$safe.pdf');
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<String> writeExportImage({
    required String documentId,
    required String name,
    required int index1Based,
    required List<int> bytes,
  }) async {
    final dir = await subdir(documentId, 'export');
    final safe = safeFileName(name);
    final dest = p.join(
      dir.path,
      '${safe}_${index1Based.toString().padLeft(2, '0')}.jpg',
    );
    await File(dest).writeAsBytes(bytes, flush: true);
    return dest;
  }

  Future<void> deleteQuietly(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Rename on-disk PDF / export images to match new document name.
  Future<ScannedDocument> renameExports(
    ScannedDocument doc,
    String newName,
  ) async {
    final exportDir = await subdir(doc.id, 'export');
    final safe = safeFileName(newName);
    String? newPdf = doc.pdfPath;
    final newImages = <String>[];

    if (doc.pdfPath != null) {
      final src = File(doc.pdfPath!);
      if (await src.exists()) {
        final dest = p.join(exportDir.path, '$safe.pdf');
        if (p.normalize(src.path) != p.normalize(dest)) {
          if (await File(dest).exists()) await File(dest).delete();
          await src.rename(dest);
        }
        newPdf = dest;
      }
    }

    for (var i = 0; i < doc.exportImagePaths.length; i++) {
      final srcPath = doc.exportImagePaths[i];
      final src = File(srcPath);
      if (!await src.exists()) continue;
      final dest = p.join(
        exportDir.path,
        '${safe}_${(i + 1).toString().padLeft(2, '0')}.jpg',
      );
      if (p.normalize(src.path) != p.normalize(dest)) {
        if (await File(dest).exists()) await File(dest).delete();
        await src.rename(dest);
      }
      newImages.add(dest);
    }

    doc.name = newName;
    doc.pdfPath = newPdf;
    doc.exportImagePaths = newImages;
    doc.updatedAt = DateTime.now();
    await saveDocument(doc);
    return doc;
  }

  /// Keep letters/digits across scripts; fall back to short id suffix.
  static String safeFileName(String name) {
    final cleaned = name
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
      return 'Scan_${DateTime.now().millisecondsSinceEpoch % 100000}';
    }
    return cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
  }

  Future<int> calculateSize(ScannedDocument doc) async {
    var total = 0;
    Future<void> add(String? path) async {
      if (path == null) return;
      final f = File(path);
      if (await f.exists()) total += await f.length();
    }

    await add(doc.pdfPath);
    await add(doc.thumbnailPath);
    for (final pth in doc.exportImagePaths) {
      await add(pth);
    }
    for (final page in doc.pages) {
      await add(page.originalImagePath);
      await add(page.processedImagePath);
    }
    return total;
  }
}
