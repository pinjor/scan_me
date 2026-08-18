import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/services/device_save_service.dart';
import '../../core/services/scan_compression.dart';
import '../../core/storage/document_storage_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../export/pdf_export_service.dart';
import '../filters/cam_scan_bw_filter.dart';

class EditorSession {
  EditorSession({
    required this.documentId,
    required this.name,
    required this.pages,
    this.selectedIndex = 0,
    this.isProcessing = false,
    this.processingLabel,
  });

  final String documentId;
  final String name;
  final List<ScannedPage> pages;
  final int selectedIndex;
  final bool isProcessing;
  final String? processingLabel;

  ScannedPage? get selectedPage =>
      pages.isEmpty ? null : pages[selectedIndex.clamp(0, pages.length - 1)];

  EditorSession copyWith({
    String? documentId,
    String? name,
    List<ScannedPage>? pages,
    int? selectedIndex,
    bool? isProcessing,
    String? processingLabel,
    bool clearProcessingLabel = false,
  }) => EditorSession(
    documentId: documentId ?? this.documentId,
    name: name ?? this.name,
    pages: pages ?? this.pages,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    isProcessing: isProcessing ?? this.isProcessing,
    processingLabel: clearProcessingLabel
        ? null
        : (processingLabel ?? this.processingLabel),
  );
}

final editorSessionProvider =
    StateNotifierProvider<EditorController, EditorSession?>(
      (ref) => EditorController(ref),
    );

class EditorController extends StateNotifier<EditorSession?> {
  EditorController(this._ref) : super(null);

  final Ref _ref;
  static const _uuid = Uuid();

  DocumentStorageService get _storage => _ref.read(documentStorageProvider);

  /// Start a new draft session from scanner JPEG paths.
  Future<void> startFromScanPaths(List<String> paths) async {
    if (paths.isEmpty) {
      throw StateError('No pages returned from scanner');
    }

    // Drop any unfinished draft before creating a new one.
    await discardUnsaved();

    final docId = _storage.newId();
    final now = DateTime.now();
    final name = 'Scan_${DateFormat('yyyy-MM-dd_HHmm').format(now)}';
    final pages = <ScannedPage>[];

    try {
      for (var i = 0; i < paths.length; i++) {
        final pageId = _uuid.v4();
        final dest = await _storage.importOriginal(
          documentId: docId,
          sourcePath: paths[i],
          pageId: pageId,
        );
        pages.add(
          ScannedPage(id: pageId, originalImagePath: dest, pageIndex: i),
        );
      }
    } catch (e) {
      await _storage.deleteDraftIfUnsaved(docId);
      rethrow;
    }

    state = EditorSession(documentId: docId, name: name, pages: pages);
    await applyFilter(PageFilter.blackAndWhite, applyToAll: true);
  }

  /// Retake-all: reuse same document id, replace page files (no orphan folder).
  Future<void> replaceAllFromScanPaths(List<String> paths) async {
    if (paths.isEmpty) {
      throw StateError('No pages returned from scanner');
    }
    final s = state;
    if (s == null) {
      await startFromScanPaths(paths);
      return;
    }

    final docId = s.documentId;
    final name = s.name;
    final oldPages = List<ScannedPage>.from(s.pages);

    final pages = <ScannedPage>[];
    try {
      for (var i = 0; i < paths.length; i++) {
        final pageId = _uuid.v4();
        final dest = await _storage.importOriginal(
          documentId: docId,
          sourcePath: paths[i],
          pageId: pageId,
        );
        pages.add(
          ScannedPage(id: pageId, originalImagePath: dest, pageIndex: i),
        );
      }
    } catch (e) {
      for (final page in pages) {
        await _storage.deleteQuietly(page.originalImagePath);
      }
      rethrow;
    }

    for (final old in oldPages) {
      await _storage.deleteQuietly(old.originalImagePath);
      await _storage.deleteQuietly(old.processedImagePath);
    }

    state = EditorSession(documentId: docId, name: name, pages: pages);
    await applyFilter(PageFilter.blackAndWhite, applyToAll: true);
  }

  /// Append newly scanned pages to the current draft (Add page).
  Future<void> appendPagesFromScanPaths(List<String> paths) async {
    if (paths.isEmpty) {
      throw StateError('No pages returned from scanner');
    }
    final s = state;
    if (s == null) {
      await startFromScanPaths(paths);
      return;
    }

    final pages = [...s.pages];
    final startIndex = pages.length;
    for (var i = 0; i < paths.length; i++) {
      final pageId = _uuid.v4();
      final dest = await _storage.importOriginal(
        documentId: s.documentId,
        sourcePath: paths[i],
        pageId: pageId,
      );
      pages.add(
        ScannedPage(
          id: pageId,
          originalImagePath: dest,
          pageIndex: startIndex + i,
        ),
      );
    }

    state = s.copyWith(pages: pages, selectedIndex: pages.length - 1);
    // applyToAll skips pages already B&W; new pages get CamScan filter.
    await applyFilter(PageFilter.blackAndWhite, applyToAll: true);
  }

  /// Clear session. Deletes draft folder only if never exported (no meta.json).
  Future<void> discardUnsaved() async {
    final s = state;
    state = null;
    if (s != null) {
      await _storage.deleteDraftIfUnsaved(s.documentId);
    }
  }

  /// Clear in-memory session after a successful export (files + meta kept).
  void clear() => state = null;

  void selectPage(int index) {
    final s = state;
    if (s == null || s.pages.isEmpty) return;
    state = s.copyWith(selectedIndex: index.clamp(0, s.pages.length - 1));
  }

  void reorder(int oldIndex, int newIndex) {
    final s = state;
    if (s == null) return;
    if (oldIndex == newIndex) return;
    final pages = [...s.pages];
    final item = pages.removeAt(oldIndex);
    pages.insert(newIndex, item);
    for (var i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageIndex: i);
    }
    var selected = s.selectedIndex;
    if (selected == oldIndex) {
      selected = newIndex;
    } else if (oldIndex < selected && newIndex >= selected) {
      selected -= 1;
    } else if (oldIndex > selected && newIndex <= selected) {
      selected += 1;
    }
    state = s.copyWith(pages: pages, selectedIndex: selected);
  }

  Future<void> deleteSelectedPage() async {
    final s = state;
    if (s == null || s.pages.isEmpty) return;
    final removed = s.pages[s.selectedIndex];
    await _storage.deleteQuietly(removed.originalImagePath);
    await _storage.deleteQuietly(removed.processedImagePath);

    final pages = [...s.pages]..removeAt(s.selectedIndex);
    for (var i = 0; i < pages.length; i++) {
      pages[i] = pages[i].copyWith(pageIndex: i);
    }
    final newIndex = pages.isEmpty
        ? 0
        : s.selectedIndex.clamp(0, pages.length - 1);
    state = s.copyWith(pages: pages, selectedIndex: newIndex);
  }

  Future<void> rotateSelected() async {
    final s = state;
    final page = s?.selectedPage;
    if (s == null || page == null) return;
    final next = (page.rotation + 90) % 360;
    final pages = [...s.pages];
    pages[s.selectedIndex] = page.copyWith(rotation: next);
    state = s.copyWith(pages: pages);
  }

  Future<void> replacePageAt(int index, String newImagePath) async {
    final s = state;
    if (s == null || index < 0 || index >= s.pages.length) return;
    final old = s.pages[index];
    await _storage.deleteQuietly(old.processedImagePath);
    final dest = await _storage.importOriginal(
      documentId: s.documentId,
      sourcePath: newImagePath,
      pageId: old.id,
    );
    final pages = [...s.pages];
    pages[index] = old.copyWith(
      originalImagePath: dest,
      selectedFilter: PageFilter.original,
      rotation: 0,
      clearProcessed: true,
    );
    state = s.copyWith(pages: pages, selectedIndex: index);
    await applyFilter(PageFilter.blackAndWhite, applyToAll: false);
  }

  Future<void> applyFilter(
    PageFilter filter, {
    required bool applyToAll,
  }) async {
    final s = state;
    if (s == null || s.pages.isEmpty) return;

    state = s.copyWith(isProcessing: true, processingLabel: 'Applying filter…');

    try {
      final pages = [...s.pages];
      final indices = applyToAll
          ? List.generate(pages.length, (i) => i)
          : [s.selectedIndex];

      // Only pages that need real work (for honest progress copy).
      final work = <int>[];
      for (final i in indices) {
        final page = pages[i];
        if (filter == PageFilter.original) {
          final oldPath = page.processedImagePath;
          pages[i] = page.copyWith(
            selectedFilter: PageFilter.original,
            clearProcessed: true,
          );
          if (oldPath != null) {
            await FileImage(File(oldPath)).evict();
          }
          continue;
        }
        if (page.selectedFilter == filter &&
            page.processedImagePath != null &&
            await File(page.processedImagePath!).exists()) {
          pages[i] = page.copyWith(selectedFilter: filter);
          continue;
        }
        work.add(i);
      }

      for (var n = 0; n < work.length; n++) {
        final i = work[n];
        final page = pages[i];
        final label = work.length <= 1
            ? 'Applying filter…'
            : 'Applying filter · ${n + 1} of ${work.length}…';
        if (state == null) return;
        state = state!.copyWith(isProcessing: true, processingLabel: label);

        final originalBytes = await File(page.originalImagePath).readAsBytes();
        if (state == null) return;
        final out = await DocumentFilterEngine.apply(
          originalBytes: originalBytes,
          filter: filter,
        );
        if (state == null) return;
        final oldPath = page.processedImagePath;
        final path = await _storage.writeProcessed(
          documentId: s.documentId,
          pageId: page.id,
          bytes: out,
          variant: filter.wire,
        );
        if (state == null) return;
        // Same-path overwrites used to leave Flutter FileImage cache stale.
        if (oldPath != null && oldPath != path) {
          await FileImage(File(oldPath)).evict();
        }
        await FileImage(File(path)).evict();
        pages[i] = page.copyWith(
          selectedFilter: filter,
          processedImagePath: path,
        );
      }

      if (state == null) return;
      state = state!.copyWith(
        pages: pages,
        isProcessing: false,
        clearProcessingLabel: true,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('applyFilter: $e\n$st');
      state = state?.copyWith(
        isProcessing: false,
        processingLabel: "Couldn't apply filter",
      );
      rethrow;
    }
  }

  void setName(String name) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(name: name);
  }

  /// Library export. [deviceSavedCount] = how many system “Save as” dialogs
  /// completed (0 if toggle off or user cancelled every one).
  Future<({ScannedDocument doc, int deviceSavedCount})> export({
    required ExportSettings settings,
    void Function(String label)? onProgress,
  }) async {
    final s = state;
    if (s == null || s.pages.isEmpty) {
      throw StateError('Nothing to export');
    }
    if (!settings.createPdf && !settings.saveImages) {
      throw StateError('Select PDF and/or images');
    }

    final pdfReady = <Uint8List>[];
    for (var i = 0; i < s.pages.length; i++) {
      final page = s.pages[i];
      onProgress?.call('Preparing page ${i + 1} of ${s.pages.length}…');
      final alreadyCompressed =
          page.selectedFilter.isProcessed && page.processedImagePath != null;
      pdfReady.add(
        await prepareExportJpeg(
          imagePath: page.displayPath,
          rotation: page.rotation,
          alreadyCompressed: alreadyCompressed,
          maxLongEdge: settings.pdfQuality.maxLongEdge,
          quality: settings.pdfQuality.jpegQuality,
          // Corner mark drawn in PDF layer so every page shows in any viewer.
          applyWatermark: false,
        ),
      );
    }

    String? pdfPath;
    final exportImages = <String>[];

    if (settings.createPdf) {
      onProgress?.call('Creating PDF…');
      final pdfBytes = await PdfExportService.buildPdfFromJpegs(
        jpegPages: pdfReady,
        pageSize: settings.pdfPageSize,
        orientation: settings.pdfOrientation,
        drawCornerWatermark: true,
        onProgress: (cur, total) {
          onProgress?.call('Creating PDF… Page $cur of $total');
        },
      );
      pdfPath = await _storage.writePdf(
        documentId: s.documentId,
        name: s.name,
        bytes: pdfBytes,
      );
    }

    if (settings.saveImages) {
      final indexes = _imageIndexes(settings, s.pages.length);
      var outIndex = 0;
      for (final i in indexes) {
        outIndex++;
        onProgress?.call('Saving images… $outIndex of ${indexes.length}');
        final page = s.pages[i];
        final alreadyCompressed =
            page.selectedFilter.isProcessed && page.processedImagePath != null;
        final bytes = await prepareExportImageBytes(
          imagePath: page.displayPath,
          rotation: page.rotation,
          alreadyCompressed: alreadyCompressed,
          format: settings.imageFormat,
          qualityPreset: settings.imageQuality,
        );
        final path = await _storage.writeExportImage(
          documentId: s.documentId,
          name: s.name,
          index1Based: outIndex,
          bytes: bytes,
          extension: settings.imageFormat == ImageExportFormat.png
              ? 'png'
              : 'jpg',
        );
        exportImages.add(path);
      }
    }

    onProgress?.call('Saving thumbnail…');
    final thumbSource = pdfReady.isNotEmpty
        ? pdfReady.first
        : await prepareExportJpeg(
            imagePath: s.pages.first.displayPath,
            rotation: s.pages.first.rotation,
            alreadyCompressed:
                s.pages.first.selectedFilter.isProcessed &&
                s.pages.first.processedImagePath != null,
          );
    final thumb = ImageCompressionService.makeThumbnail(thumbSource);
    final thumbPath = await _storage.writeThumbnail(
      documentId: s.documentId,
      bytes: thumb,
    );

    final existing = await _storage.loadDocument(s.documentId);
    final now = DateTime.now();
    final doc = ScannedDocument(
      id: s.documentId,
      name: s.name,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      pages: [...s.pages],
      thumbnailPath: thumbPath,
      pdfPath: pdfPath ?? existing?.pdfPath,
      exportImagePaths: exportImages.isNotEmpty
          ? exportImages
          : (existing?.exportImagePaths ?? []),
      folderId: existing?.folderId,
      tags: existing?.tags ?? const [],
      isFavorite: existing?.isFavorite ?? false,
      deletedAt: existing?.deletedAt,
      exportedAt: now,
    );
    doc.fileSizeBytes = await _storage.calculateSize(doc);
    await _storage.saveDocument(doc);
    await _ref.read(documentsProvider.notifier).refresh();

    var deviceSavedCount = 0;
    if (settings.alsoSaveToDevice) {
      onProgress?.call('Saving to device…');
      try {
        if (pdfPath != null) {
          final where = await DeviceSaveService.saveFile(sourcePath: pdfPath);
          if (where != null) deviceSavedCount++;
        }
        for (final path in exportImages) {
          final where = await DeviceSaveService.saveFile(sourcePath: path);
          if (where != null) deviceSavedCount++;
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('alsoSaveToDevice: $e\n$st');
        // Library save already succeeded — device copy is optional.
      }
    }

    return (doc: doc, deviceSavedCount: deviceSavedCount);
  }

  List<int> _imageIndexes(ExportSettings settings, int pageCount) {
    switch (settings.imageScope) {
      case ImageExportScope.currentPage:
        final i = settings.currentPageIndex.clamp(0, pageCount - 1);
        return [i];
      case ImageExportScope.selectedPages:
        final selected =
            settings.selectedPageIndexes
                .where((i) => i >= 0 && i < pageCount)
                .toList()
              ..sort();
        if (selected.isEmpty) {
          return List.generate(pageCount, (i) => i);
        }
        return selected;
      case ImageExportScope.entireDocument:
        return List.generate(pageCount, (i) => i);
    }
  }
}
