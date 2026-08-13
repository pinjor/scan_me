import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/providers.dart';
import '../../core/services/scan_compression.dart';
import '../../core/storage/document_storage_service.dart';
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
          ScannedPage(
            id: pageId,
            originalImagePath: dest,
            pageIndex: i,
          ),
        );
      }
    } catch (e) {
      await _storage.deleteDraftIfUnsaved(docId);
      rethrow;
    }

    state = EditorSession(
      documentId: docId,
      name: name,
      pages: pages,
    );
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
    await _storage.clearWorkingFiles(docId);

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
          ScannedPage(
            id: pageId,
            originalImagePath: dest,
            pageIndex: i,
          ),
        );
      }
    } catch (e) {
      // Leave empty session folder; caller may discard.
      rethrow;
    }

    state = EditorSession(
      documentId: docId,
      name: name,
      pages: pages,
    );
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

      for (final i in indices) {
        final page = pages[i];
        if (filter == PageFilter.original) {
          pages[i] = page.copyWith(
            selectedFilter: PageFilter.original,
            clearProcessed: true,
          );
          continue;
        }

        // Skip recompute if already B&W processed.
        if (page.selectedFilter == PageFilter.blackAndWhite &&
            page.processedImagePath != null &&
            await File(page.processedImagePath!).exists()) {
          pages[i] = page.copyWith(selectedFilter: filter);
          continue;
        }

        state = state!.copyWith(
          isProcessing: true,
          processingLabel: 'Filter page ${i + 1} of ${indices.length}…',
        );

        final originalBytes = await File(page.originalImagePath).readAsBytes();
        final out = await DocumentFilterEngine.apply(
          originalBytes: originalBytes,
          filter: filter,
        );
        final path = await _storage.writeProcessed(
          documentId: s.documentId,
          pageId: page.id,
          bytes: out,
        );
        pages[i] = page.copyWith(
          selectedFilter: filter,
          processedImagePath: path,
        );
      }

      state = state!.copyWith(
        pages: pages,
        isProcessing: false,
        clearProcessingLabel: true,
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('applyFilter: $e\n$st');
      state = state?.copyWith(
        isProcessing: false,
        processingLabel: 'Filter failed',
      );
      rethrow;
    }
  }

  void setName(String name) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(name: name);
  }

  Future<ScannedDocument> export({
    required bool createPdf,
    required bool saveImages,
    void Function(String label)? onProgress,
  }) async {
    final s = state;
    if (s == null || s.pages.isEmpty) {
      throw StateError('Nothing to export');
    }

    // Compress (+ rotate) once per page; do not write into processed/ for Original.
    final ready = <Uint8List>[];
    for (var i = 0; i < s.pages.length; i++) {
      final page = s.pages[i];
      onProgress?.call('Preparing page ${i + 1} of ${s.pages.length}…');
      final alreadyCompressed =
          page.selectedFilter == PageFilter.blackAndWhite &&
          page.processedImagePath != null;
      ready.add(
        await prepareExportJpeg(
          imagePath: page.displayPath,
          rotation: page.rotation,
          alreadyCompressed: alreadyCompressed,
        ),
      );
    }

    String? pdfPath;
    final exportImages = <String>[];

    if (createPdf) {
      onProgress?.call('Creating PDF…');
      final pdfBytes = await PdfExportService.buildPdfFromJpegs(
        jpegPages: ready,
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

    if (saveImages) {
      for (var i = 0; i < ready.length; i++) {
        onProgress?.call('Saving images… ${i + 1} of ${ready.length}');
        final path = await _storage.writeExportImage(
          documentId: s.documentId,
          name: s.name,
          index1Based: i + 1,
          bytes: ready[i],
        );
        exportImages.add(path);
      }
    }

    // Thumbnail respects rotation (from prepared bytes).
    onProgress?.call('Saving thumbnail…');
    final thumb = ImageCompressionService.makeThumbnail(ready.first);
    final thumbPath = await _storage.writeThumbnail(
      documentId: s.documentId,
      bytes: thumb,
    );

    // Persist page metadata without polluting Original with export paths.
    final pages = [...s.pages];

    final now = DateTime.now();
    final doc = ScannedDocument(
      id: s.documentId,
      name: s.name,
      createdAt: now,
      updatedAt: now,
      pages: pages,
      thumbnailPath: thumbPath,
      pdfPath: pdfPath,
      exportImagePaths: exportImages,
    );
    doc.fileSizeBytes = await _storage.calculateSize(doc);
    await _storage.saveDocument(doc);
    await _ref.read(documentsProvider.notifier).refresh();
    return doc;
  }
}
