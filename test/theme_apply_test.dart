import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanme/core/onboarding.dart';
import 'package:scanme/core/providers.dart';
import 'package:scanme/core/theme/app_theme.dart';
import 'package:scanme/main.dart';
import 'package:scanme/shared/models/library_models.dart';
import 'package:scanme/shared/models/scanned_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('builtin schemes pin the card swatch as ColorScheme.primary', () {
    for (final spec in kBuiltinThemes) {
      if (spec.brand) continue;
      final light = spec.scheme(Brightness.light);
      expect(
        light.primary.toARGB32(),
        spec.primaryColor.toARGB32(),
        reason: '${spec.name} light primary',
      );
      final dark = spec.scheme(Brightness.dark);
      expect(
        dark.primary.toARGB32(),
        spec.primaryColor.toARGB32(),
        reason: '${spec.name} dark primary',
      );
      if (spec.secondary != null) {
        expect(
          light.secondary.toARGB32(),
          spec.secondaryColor!.toARGB32(),
          reason: '${spec.name} secondary',
        );
      }
      if (spec.tertiary != null) {
        expect(
          light.tertiary.toARGB32(),
          spec.tertiaryColor!.toARGB32(),
          reason: '${spec.name} tertiary',
        );
      }
    }
  });

  test('ScanMe brand stays hand-tuned, not the raw seed', () {
    final spec = kBuiltinThemes.first;
    expect(spec.brand, isTrue);
    final theme = AppTheme.light(spec);
    expect(theme.colorScheme.primary, AppTheme.navy);
  });

  test('Sunset ThemeData primary is orange, not navy', () {
    final sunset = kBuiltinThemes.firstWhere((s) => s.id == 'sunset');
    final theme = AppTheme.light(sunset);
    expect(theme.colorScheme.primary.toARGB32(), 0xFFC45C26);
    expect(theme.colorScheme.primary, isNot(AppTheme.navy));
  });

  testWidgets('tapping a theme recolors the live ColorScheme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentsProvider.overrideWith((ref) => _FakeDocs()),
          foldersProvider.overrideWith((ref) => _FakeFolders()),
          onboardingProvider.overrideWith(
            (ref) => OnboardingController.completed(),
          ),
        ],
        child: const ScanMeApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunset'));
    await tester.pumpAndSettle();

    final ctx = tester.element(find.text('Sunset'));
    expect(
      Theme.of(ctx).colorScheme.primary.toARGB32(),
      0xFFC45C26,
    );
  });
}

class _FakeDocs extends StateNotifier<AsyncValue<List<ScannedDocument>>>
    implements DocumentsController {
  _FakeDocs() : super(const AsyncValue.data([]));

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

class _FakeFolders extends StateNotifier<AsyncValue<List<DocFolder>>>
    implements FoldersController {
  _FakeFolders() : super(const AsyncValue.data([]));

  @override
  Future<void> refresh() async {}

  @override
  Future<DocFolder?> create(String name) async => null;

  @override
  Future<void> rename(String id, String name) async {}

  @override
  Future<void> delete(String id) async {}
}
