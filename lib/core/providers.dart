import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/document_storage_service.dart';
import '../features/scanner/document_scanner_service.dart';
import '../shared/models/scanned_document.dart';

final documentStorageProvider = Provider<DocumentStorageService>(
  (ref) => DocumentStorageService(),
);

final documentScannerProvider = Provider<DocumentScannerService>(
  (ref) => DocumentScannerService(),
);

final documentsProvider =
    StateNotifierProvider<DocumentsController, AsyncValue<List<ScannedDocument>>>(
      (ref) => DocumentsController(ref.watch(documentStorageProvider)),
    );

class DocumentsController
    extends StateNotifier<AsyncValue<List<ScannedDocument>>> {
  DocumentsController(this._storage) : super(const AsyncValue.loading()) {
    refresh();
  }

  final DocumentStorageService _storage;

  Future<void> refresh() async {
    try {
      await _storage.purgeOrphanDrafts();
      final list = await _storage.listDocuments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upsert(ScannedDocument doc) async {
    await _storage.saveDocument(doc);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _storage.deleteDocument(id);
    await refresh();
  }

  Future<void> rename(String id, String name) async {
    final doc = await _storage.loadDocument(id);
    if (doc == null) return;
    final trimmed = name.trim().isEmpty ? doc.name : name.trim();
    await _storage.renameExports(doc, trimmed);
    await refresh();
  }
}
