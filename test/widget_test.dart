import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanme/core/providers.dart';
import 'package:scanme/main.dart';
import 'package:scanme/shared/models/library_models.dart';
import 'package:scanme/shared/models/scanned_document.dart';

void main() {
  testWidgets('ScanMe home loads', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith(
            (ref) => _FakeDocumentsController(),
          ),
          foldersProvider.overrideWith(
            (ref) => _FakeFoldersController(),
          ),
        ],
        child: const ScanMeApp(),
      ),
    );
    await tester.pump();
    expect(find.text('ScanMe'), findsOneWidget);
    expect(find.text('No documents yet'), findsOneWidget);
  });
}

class _FakeDocumentsController
    extends StateNotifier<AsyncValue<List<ScannedDocument>>>
    implements DocumentsController {
  _FakeDocumentsController() : super(const AsyncValue.data([]));

  @override
  Future<void> refresh() async {}

  @override
  Future<void> upsert(ScannedDocument doc) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> restore(String id) async {}

  @override
  Future<void> permanentlyDelete(String id) async {}

  @override
  Future<void> rename(String id, String name) async {}

  @override
  Future<void> setFavorite(String id, bool value) async {}

  @override
  Future<void> setFolder(String id, String? folderId) async {}

  @override
  Future<void> setTags(String id, List<String> tags) async {}

  @override
  Future<void> addTag(String id, String tag) async {}

  @override
  Future<void> removeTag(String id, String tag) async {}

  @override
  Future<void> toggleTag(String id, String tagId) async {}
}

class _FakeFoldersController
    extends StateNotifier<AsyncValue<List<DocFolder>>>
    implements FoldersController {
  _FakeFoldersController() : super(const AsyncValue.data([]));

  @override
  Future<void> refresh() async {}

  @override
  Future<DocFolder?> create(String name) async => null;

  @override
  Future<void> rename(String id, String name) async {}

  @override
  Future<void> delete(String id) async {}
}
