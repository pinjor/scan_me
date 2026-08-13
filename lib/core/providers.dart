import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage/document_storage_service.dart';
import '../features/scanner/document_scanner_service.dart';
import '../shared/models/library_models.dart';
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

final foldersProvider =
    StateNotifierProvider<FoldersController, AsyncValue<List<DocFolder>>>(
      (ref) => FoldersController(ref.watch(documentStorageProvider)),
    );

final libraryQueryProvider =
    StateNotifierProvider<LibraryQueryController, LibraryQuery>(
      (ref) => LibraryQueryController(),
    );

class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.folderId,
    this.unfiledOnly = false,
    this.tag,
    this.favoritesOnly = false,
    this.showTrash = false,
    this.sort = LibrarySort.recentlyModified,
    this.favoritesFirst = true,
  });

  final String search;
  /// null = all folders; otherwise filter by this folder id.
  final String? folderId;
  final bool unfiledOnly;
  final String? tag;
  final bool favoritesOnly;
  final bool showTrash;
  final LibrarySort sort;
  final bool favoritesFirst;

  LibraryQuery copyWith({
    String? search,
    String? folderId,
    bool clearFolder = false,
    bool? unfiledOnly,
    String? tag,
    bool clearTag = false,
    bool? favoritesOnly,
    bool? showTrash,
    LibrarySort? sort,
    bool? favoritesFirst,
  }) =>
      LibraryQuery(
        search: search ?? this.search,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        unfiledOnly: unfiledOnly ?? this.unfiledOnly,
        tag: clearTag ? null : (tag ?? this.tag),
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
        showTrash: showTrash ?? this.showTrash,
        sort: sort ?? this.sort,
        favoritesFirst: favoritesFirst ?? this.favoritesFirst,
      );
}

class LibraryQueryController extends StateNotifier<LibraryQuery> {
  LibraryQueryController() : super(const LibraryQuery());

  void setSearch(String v) => state = state.copyWith(search: v);

  void setFolder(String? id, {bool unfiled = false}) => state = state.copyWith(
        folderId: id,
        clearFolder: id == null && !unfiled,
        unfiledOnly: unfiled,
      );

  void setTag(String? tag) => state = state.copyWith(
        tag: tag,
        clearTag: tag == null,
      );

  void setFavoritesOnly(bool v) => state = state.copyWith(favoritesOnly: v);

  void setShowTrash(bool v) => state = state.copyWith(showTrash: v);

  void setSort(LibrarySort sort) => state = state.copyWith(sort: sort);

  void setFavoritesFirst(bool v) => state = state.copyWith(favoritesFirst: v);
}

class FoldersController extends StateNotifier<AsyncValue<List<DocFolder>>> {
  FoldersController(this._storage) : super(const AsyncValue.loading()) {
    refresh();
  }

  final DocumentStorageService _storage;

  Future<void> refresh() async {
    try {
      final list = await _storage.listFolders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<DocFolder?> create(String name) async {
    final folder = await _storage.createFolder(name);
    await refresh();
    return folder;
  }

  Future<void> rename(String id, String name) async {
    await _storage.renameFolder(id, name);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _storage.deleteFolder(id);
    await refresh();
  }
}

class DocumentsController
    extends StateNotifier<AsyncValue<List<ScannedDocument>>> {
  DocumentsController(this._storage) : super(const AsyncValue.loading()) {
    refresh();
  }

  final DocumentStorageService _storage;

  Future<void> refresh() async {
    try {
      await _storage.purgeOrphanDrafts();
      await _storage.purgeExpiredTrash();
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

  /// Soft-delete → Trash.
  Future<void> delete(String id) async {
    await _storage.moveToTrash(id);
    await refresh();
  }

  Future<void> restore(String id) async {
    await _storage.restoreFromTrash(id);
    await refresh();
  }

  Future<void> permanentlyDelete(String id) async {
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

  Future<void> setFavorite(String id, bool value) async {
    await _storage.updateDocumentMeta(id, isFavorite: value);
    await refresh();
  }

  Future<void> setFolder(String id, String? folderId) async {
    await _storage.updateDocumentMeta(
      id,
      folderId: folderId,
      clearFolder: folderId == null,
    );
    await refresh();
  }

  Future<void> setTags(String id, List<String> tags) async {
    final cleaned = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await _storage.updateDocumentMeta(id, tags: cleaned);
    await refresh();
  }

  Future<void> addTag(String id, String tag) async {
    final doc = await _storage.loadDocument(id);
    if (doc == null) return;
    final next = [...doc.tags];
    final t = tag.trim();
    if (t.isEmpty || next.any((e) => e.toLowerCase() == t.toLowerCase())) {
      return;
    }
    next.add(t);
    await setTags(id, next);
  }

  Future<void> removeTag(String id, String tag) async {
    final doc = await _storage.loadDocument(id);
    if (doc == null) return;
    await setTags(
      id,
      doc.tags.where((t) => t.toLowerCase() != tag.toLowerCase()).toList(),
    );
  }
}

/// Apply [query] + optional [folders] for display sorting/filtering.
List<ScannedDocument> filterAndSortDocuments(
  List<ScannedDocument> all,
  LibraryQuery query,
) {
  Iterable<ScannedDocument> list = all.where((d) {
    if (query.showTrash) return d.isInTrash;
    return !d.isInTrash;
  });

  if (query.favoritesOnly) {
    list = list.where((d) => d.isFavorite);
  }
  if (query.unfiledOnly) {
    list = list.where((d) => d.folderId == null);
  } else if (query.folderId != null) {
    list = list.where((d) => d.folderId == query.folderId);
  }
  if (query.tag != null && query.tag!.isNotEmpty) {
    final needle = query.tag!.toLowerCase();
    list = list.where(
      (d) => d.tags.any((t) => t.toLowerCase() == needle),
    );
  }
  final q = query.search.trim().toLowerCase();
  if (q.isNotEmpty) {
    list = list.where((d) {
      if (d.name.toLowerCase().contains(q)) return true;
      if (d.tags.any((t) => t.toLowerCase().contains(q))) return true;
      return false;
    });
  }

  final out = list.toList();
  int cmp(ScannedDocument a, ScannedDocument b) {
    if (query.favoritesFirst && a.isFavorite != b.isFavorite) {
      return a.isFavorite ? -1 : 1;
    }
    switch (query.sort) {
      case LibrarySort.recentlyModified:
        return b.updatedAt.compareTo(a.updatedAt);
      case LibrarySort.recentlyCreated:
        return b.createdAt.compareTo(a.createdAt);
      case LibrarySort.nameAsc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case LibrarySort.nameDesc:
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case LibrarySort.pageCount:
        return b.pageCount.compareTo(a.pageCount);
      case LibrarySort.fileSize:
        return (b.fileSizeBytes ?? 0).compareTo(a.fileSizeBytes ?? 0);
    }
  }

  out.sort(cmp);
  return out;
}

Set<String> collectAllTags(List<ScannedDocument> docs) {
  final tags = <String>{};
  for (final d in docs) {
    if (d.isInTrash) continue;
    tags.addAll(d.tags);
  }
  return tags;
}
