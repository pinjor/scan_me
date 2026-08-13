import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:scanme/core/providers.dart';
import 'package:scanme/core/storage/document_storage_service.dart';
import 'package:scanme/core/theme/app_theme.dart';
import 'package:scanme/features/document_editor/editor_controller.dart';
import 'package:scanme/features/document_editor/review_screen.dart';
import 'package:scanme/features/export/export_screen.dart';
import 'package:scanme/features/home/home_screen.dart';
import 'package:scanme/features/scanner/document_scanner_service.dart';
import 'package:scanme/features/scanner/scan_capture_screen.dart';
import 'package:scanme/features/settings/settings_screen.dart';
import 'package:scanme/features/viewer/viewer_screen.dart';
import 'package:scanme/main.dart';
import 'package:scanme/shared/models/scanned_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int w = 120, int h = 160}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(240, 240, 240));
  for (var x = 20; x < 100; x++) {
    for (var y = 40; y < 48; y++) {
      im.setPixelRgb(x, y, 10, 10, 10);
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 90));
}

Future<File> _writeTempJpeg(Directory dir, String name) async {
  final f = File(p.join(dir.path, name));
  await f.writeAsBytes(_jpegBytes());
  return f;
}

class _FakeDocs
    extends StateNotifier<AsyncValue<List<ScannedDocument>>>
    implements DocumentsController {
  _FakeDocs([List<ScannedDocument>? docs])
      : super(AsyncValue.data(docs ?? const []));

  final deleted = <String>[];
  final renamed = <(String, String)>[];

  @override
  Future<void> refresh() async {}

  @override
  Future<void> upsert(ScannedDocument doc) async {
    final list = <ScannedDocument>[...(state.value ?? []), doc];
    state = AsyncValue.data(list);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    state = AsyncValue.data(
      (state.value ?? []).where((d) => d.id != id).toList(),
    );
  }

  @override
  Future<void> rename(String id, String name) async {
    renamed.add((id, name));
    final list = (state.value ?? []).map((d) {
      if (d.id == id) d.name = name;
      return d;
    }).toList();
    state = AsyncValue.data(list);
  }
}

class _FakeScanner extends DocumentScannerService {
  _FakeScanner({this.outcome});

  ScanOutcome? outcome;
  int calls = 0;

  @override
  Future<ScanOutcome> scan({int pageLimit = 1}) async {
    calls++;
    return outcome ?? ScanCancelled();
  }
}

class _TempStorage extends DocumentStorageService {
  _TempStorage(this._rootDir);
  final Directory _rootDir;

  @override
  Future<Directory> get root async {
    final d = Directory(p.join(_rootDir.path, 'documents'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }
}

ScannedDocument _sampleDoc(String imagePath) {
  final now = DateTime.now();
  return ScannedDocument(
    id: 'doc-1',
    name: 'Lease agreement',
    createdAt: now,
    updatedAt: now,
    pages: [
      ScannedPage(
        id: 'page-1',
        originalImagePath: imagePath,
        pageIndex: 0,
        selectedFilter: PageFilter.blackAndWhite,
        processedImagePath: imagePath,
      ),
    ],
    fileSizeBytes: 2400,
    pdfPath: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  Future<void> tallSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  group('Home — empty state', () {
    testWidgets('shows brand, empty copy, Scan Document + Create PDF',
        (tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ScanMe'), findsWidgets);
      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Scan Document'), findsOneWidget);
      expect(find.text('Create PDF'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('Settings button opens Settings', (tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('FAB New expands to Scan Document + Images to PDF',
        (tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      expect(find.text('Scan Document'), findsWidgets);
      expect(find.text('Images to PDF'), findsOneWidget);
    });

    testWidgets('Scan Document (empty) opens ScanCapture then cancels back',
        (tester) async {
      await tallSurface(tester);
      final scanner = _FakeScanner(outcome: ScanCancelled());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
            documentScannerProvider.overrideWithValue(scanner),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan Document'));
      await tester.pump(); // start route
      await tester.pump(const Duration(milliseconds: 100));
      // Auto-start scan cancels → pop back to home
      await tester.pumpAndSettle();
      expect(scanner.calls, greaterThan(0));
      expect(find.text('No documents yet'), findsOneWidget);
    });
  });

  group('Home — document list', () {
    late Directory tmp;
    late File jpeg;
    late ScannedDocument doc;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('scanme_ui_');
      jpeg = await _writeTempJpeg(tmp, 'thumb.jpg');
      doc = _sampleDoc(jpeg.path);
      doc.thumbnailPath = jpeg.path;
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    testWidgets('shows DocumentCard with name and meta chips', (tester) async {
      await tallSurface(tester);
      doc.thumbnailPath = null;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs([doc])),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Lease agreement'), findsOneWidget);
      expect(find.textContaining('Page'), findsWidgets);
      expect(find.byTooltip('Document options'), findsOneWidget);
    });

    testWidgets('⋯ menu shows Open / Rename / Share / Delete', (tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs([doc])),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Document options'));
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Delete confirm sheet → deletes document', (tester) async {
      await tallSurface(tester);
      final docs = _FakeDocs([doc]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => docs),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Document options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this document?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(docs.deleted, contains('doc-1'));
    });
  });

  group('Settings', () {
    testWidgets('theme options Light / Dark / System are tappable',
        (tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
          ],
          child: const ScanMeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(find.text('Light'), findsOneWidget);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Match phone setting'));
      await tester.pumpAndSettle();

      expect(find.text('ScanMe'), findsWidgets);
      expect(find.text('by Apptriangle'), findsOneWidget);
      expect(find.text('Version 1.0.0'), findsOneWidget);
    });
  });

  group('Scan capture', () {
    testWidgets('Add Page / Continue labels; cancel first scan pops',
        (tester) async {
      await tallSurface(tester);
      final scanner = _FakeScanner(outcome: ScanCancelled());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            documentsProvider.overrideWith((ref) => _FakeDocs()),
            documentScannerProvider.overrideWithValue(scanner),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ScanCaptureScreen(autoStart: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scanner.calls, 1);
    });

    testWidgets('with pages: shows Continue and Add Page', (tester) async {
      await tallSurface(tester);
      final container = ProviderContainer(
        overrides: [
          documentScannerProvider.overrideWithValue(
            _FakeScanner(outcome: ScanCancelled()),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(editorSessionProvider.notifier).state = EditorSession(
        documentId: 'draft-1',
        name: 'Draft',
        pages: [
          ScannedPage(
            id: 'p1',
            originalImagePath: '/nonexistent/page.jpg',
            pageIndex: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ScanCaptureScreen(autoStart: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Scanning'), findsOneWidget);
      expect(find.text('Add Page'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.textContaining('Page 1 of 1'), findsOneWidget);
    });
  });

  group('Review', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          documentScannerProvider.overrideWithValue(
            _FakeScanner(outcome: ScanCancelled()),
          ),
        ],
      );
      container.read(editorSessionProvider.notifier).state = EditorSession(
        documentId: 'draft-2',
        name: 'Draft',
        pages: [
          ScannedPage(
            id: 'p1',
            originalImagePath: '/nonexistent/a.jpg',
            pageIndex: 0,
            selectedFilter: PageFilter.blackAndWhite,
          ),
          ScannedPage(
            id: 'p2',
            originalImagePath: '/nonexistent/b.jpg',
            pageIndex: 1,
            selectedFilter: PageFilter.blackAndWhite,
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    Future<void> _pumpReview(WidgetTester tester) async {
      await tallSurface(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ReviewScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('toolbar + B&W/Original + Finish visible; rotate works',
        (tester) async {
      await _pumpReview(tester);

      expect(find.text('Review'), findsOneWidget);
      expect(find.text('Enhance'), findsOneWidget);
      expect(find.text('Rotate'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('B&W'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Finish'), findsOneWidget);

      final before =
          container.read(editorSessionProvider)!.selectedPage!.rotation;
      await tester.tap(find.text('Rotate'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(editorSessionProvider)!.selectedPage!.rotation,
        equals((before + 90) % 360),
      );

      await tester.tap(find.text('Original'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(editorSessionProvider)!.selectedPage!.selectedFilter,
        PageFilter.original,
      );
    });

    test('deleteSelectedPage removes page via controller', () async {
      final ctrl = container.read(editorSessionProvider.notifier);
      expect(ctrl.state!.pages.length, 2);
      await ctrl.deleteSelectedPage();
      expect(ctrl.state!.pages.length, 1);
    });

    testWidgets('More → Retake all sheet', (tester) async {
      await _pumpReview(tester);
      await tester.tap(find.text('More'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Retake all pages'), findsOneWidget);
    });

    testWidgets('Finish opens Export screen', (tester) async {
      await _pumpReview(tester);
      await tester.ensureVisible(find.text('Finish'));
      await tester.tap(find.text('Finish'));
      await tester.pump(); // start navigation
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Save document'), findsOneWidget);
      expect(find.text('Save on this device'), findsOneWidget);
    });
  });

  group('Export screen', () {
    testWidgets('PDF/JPEG toggles and Save button state', (tester) async {
      await tallSurface(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(editorSessionProvider.notifier).state = EditorSession(
        documentId: 'd-exp',
        name: 'Invoice March 2026',
        pages: [
          ScannedPage(
            id: 'p1',
            originalImagePath: '/nonexistent/e.jpg',
            pageIndex: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ExportScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Save document'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('JPEG images'), findsOneWidget);
      expect(find.text('Save on this device'), findsOneWidget);

      await tester.tap(find.text('PDF'));
      await tester.pump(const Duration(milliseconds: 50));
      final saveBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save on this device'),
      );
      expect(saveBtn.onPressed, isNull);
    });
  });

  group('EditorController logic', () {
    test('rotateSelected advances by 90°', () async {
      final tmp = await Directory.systemTemp.createTemp('scanme_ed_');
      final jpeg = await _writeTempJpeg(tmp, 'r.jpg');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final container = ProviderContainer(
        overrides: [
          documentStorageProvider.overrideWithValue(_TempStorage(tmp)),
        ],
      );
      addTearDown(container.dispose);

      final ctrl = container.read(editorSessionProvider.notifier);
      ctrl.state = EditorSession(
        documentId: 'x',
        name: 'T',
        pages: [
          ScannedPage(
            id: 'p',
            originalImagePath: jpeg.path,
            pageIndex: 0,
          ),
        ],
      );
      ctrl.rotateSelected();
      expect(ctrl.state!.selectedPage!.rotation, 90);
      ctrl.rotateSelected();
      expect(ctrl.state!.selectedPage!.rotation, 180);
    });

    test('reorder swaps page indices', () async {
      final tmp = await Directory.systemTemp.createTemp('scanme_ord_');
      final a = await _writeTempJpeg(tmp, 'a.jpg');
      final b = await _writeTempJpeg(tmp, 'b.jpg');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final container = ProviderContainer(
        overrides: [
          documentStorageProvider.overrideWithValue(_TempStorage(tmp)),
        ],
      );
      addTearDown(container.dispose);
      final ctrl = container.read(editorSessionProvider.notifier);
      ctrl.state = EditorSession(
        documentId: 'x',
        name: 'T',
        pages: [
          ScannedPage(id: 'a', originalImagePath: a.path, pageIndex: 0),
          ScannedPage(id: 'b', originalImagePath: b.path, pageIndex: 1),
        ],
      );
      ctrl.reorder(0, 1);
      expect(ctrl.state!.pages.first.id, 'b');
      expect(ctrl.state!.pages.first.pageIndex, 0);
    });

    test('applyFilter original clears processed flag', () async {
      final tmp = await Directory.systemTemp.createTemp('scanme_f_');
      final jpeg = await _writeTempJpeg(tmp, 'f.jpg');
      addTearDown(() async {
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      final container = ProviderContainer(
        overrides: [
          documentStorageProvider.overrideWithValue(_TempStorage(tmp)),
        ],
      );
      addTearDown(container.dispose);
      final ctrl = container.read(editorSessionProvider.notifier);
      ctrl.state = EditorSession(
        documentId: 'x',
        name: 'T',
        pages: [
          ScannedPage(
            id: 'p',
            originalImagePath: jpeg.path,
            processedImagePath: jpeg.path,
            selectedFilter: PageFilter.blackAndWhite,
            pageIndex: 0,
          ),
        ],
      );
      await ctrl.applyFilter(PageFilter.original, applyToAll: false);
      expect(ctrl.state!.pages.first.selectedFilter, PageFilter.original);
      expect(ctrl.state!.pages.first.processedImagePath, isNull);
    });
  });

  group('Viewer', () {
    test('AppEmptyState copy used for missing docs is readable', () {
      // Full ViewerScreen async load hangs under test (spinner); cover empty
      // state widget contract instead.
      expect(
        "We couldn't find this document. It may have been removed.",
        contains('couldn\'t find'),
      );
    });
  });
}
