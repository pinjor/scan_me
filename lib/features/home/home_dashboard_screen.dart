import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_surface.dart';
import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/document_card.dart';
import '../file_viewer/file_viewer_screen.dart';
import '../viewer/viewer_screen.dart';
import 'library_actions.dart';
import 'library_filter_bar.dart';

/// Home: search · library list.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenTools,
    this.isActive = true,
  });

  final VoidCallback onOpenTools;

  /// False when another shell tab is showing (KeepAlive still mounts this).
  final bool isActive;

  @override
  ConsumerState<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void didUpdateWidget(HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _searchFocus.unfocus();
    }
    if (!oldWidget.isActive && widget.isActive) {
      // Silent disk refresh — keep last Continue list on screen.
      ref.read(convertOutputsProvider.notifier).refresh();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _dismissSearch() {
    if (_searchFocus.hasFocus) _searchFocus.unfocus();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _syncSearch(LibraryQuery query) {
    if (_searchCtrl.text == query.search) return;
    _searchCtrl.value = TextEditingValue(
      text: query.search,
      selection: TextSelection.collapsed(offset: query.search.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final convertsAsync = ref.watch(convertOutputsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final query = ref.watch(libraryQueryProvider);
    _syncSearch(query);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final bottomClear = 88.0 + MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: GestureDetector(
        onTap: _dismissSearch,
        behavior: HitTestBehavior.deferToChild,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(documentsProvider.notifier).refresh();
            await ref.read(convertOutputsProvider.notifier).refresh();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(),
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text('ScanMe', style: text.headlineSmall),
                          ],
                        ),
                      ),
                      AppCircleIconButton(
                        icon: Theme.of(context).brightness == Brightness.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        tooltip: Theme.of(context).brightness == Brightness.dark
                            ? 'Light mode'
                            : 'Dark mode',
                        size: 44,
                        onPressed: () {
                          final next =
                              Theme.of(context).brightness == Brightness.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                          ref.read(themeModeProvider.notifier).setMode(next);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AppSearchBar(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    dense: true,
                    onChanged: (v) =>
                        ref.read(libraryQueryProvider.notifier).setSearch(v),
                    onSubmitted: (_) => _dismissSearch(),
                    onClear: () {
                      _dismissSearch();
                      ref.read(libraryQueryProvider.notifier).setSearch('');
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: LibraryFilterBar()),
              docsAsync.when(
                loading: () => SliverToBoxAdapter(
                  child: SizedBox(
                    height: 240,
                    child: AppListSkeleton(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClear),
                    ),
                  ),
                ),
                error: (_, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppErrorState(
                    title: "Couldn't load documents",
                    subtitle: 'Check storage and try again.',
                    onRetry: () =>
                        ref.read(documentsProvider.notifier).refresh(),
                  ),
                ),
                data: (all) {
                  final tagCatalog = tagsAsync.valueOrNull ?? const <TagDef>[];
                  final tagNamesById = {
                    for (final t in tagCatalog) t.id: t.name,
                  };
                  final searching = query.search.trim().isNotEmpty;
                  final docs = filterAndSortDocuments(
                    all,
                    query.copyWith(favoritesFirst: false),
                    tagNamesById: tagNamesById,
                  );
                  final converts = kScanOnlySurface || query.showTrash
                      ? const <ConvertOutput>[]
                      : filterConvertOutputs(
                          convertsAsync.valueOrNull ?? const [],
                          query,
                          tagNamesById: tagNamesById,
                        );

                  final entries = <_ContinueEntry>[
                    for (final d in docs) _ContinueDoc(d),
                    for (final c in converts) _ContinueConvert(c),
                  ];
                  _sortLibraryEntries(entries, query.sort);

                  if (entries.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _libraryEmpty(
                        query: query,
                        searching: searching,
                      ),
                    );
                  }
                  final tagDefs = tagsAsync.valueOrNull ?? const <TagDef>[];
                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, bottomClear),
                    sliver: SliverList.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return FadeRiseIn(
                          child: switch (entry) {
                            _ContinueDoc(:final doc) => DocumentCard(
                              doc: doc,
                              tagDefs: tagDefs,
                              onOpen: () => AppPageRoute.push(
                                context,
                                ViewerScreen(documentId: doc.id),
                              ),
                              onFavorite: query.showTrash
                                  ? null
                                  : () => ref
                                        .read(documentsProvider.notifier)
                                        .setFavorite(doc.id, !doc.isFavorite),
                              onMore: () => showLibraryDocActions(
                                context: context,
                                ref: ref,
                                doc: doc,
                                trash: query.showTrash,
                              ),
                            ),
                            _ContinueConvert(:final output) =>
                              _ConvertContinueCard(
                                output: output,
                                tagDefs: tagDefs,
                                onOpen: () => FileViewerScreen.open(
                                  context,
                                  output.path,
                                  title: output.name,
                                ),
                                onFavorite: () => ref
                                    .read(convertOutputsProvider.notifier)
                                    .setFavorite(
                                      output.path,
                                      !output.isFavorite,
                                    ),
                                onMore: () => showConvertLibraryActions(
                                  context: context,
                                  ref: ref,
                                  output: output,
                                ),
                              ),
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _libraryEmpty({
    required LibraryQuery query,
    required bool searching,
  }) {
    const pad = EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    if (query.showTrash) {
      return AppEmptyState(
        padding: pad,
        title: 'Nothing in Trash',
        subtitle: 'Deleted scans land here.',
        primaryLabel: 'Back to library',
        onPrimary: () => ref.read(libraryQueryProvider.notifier).showAll(),
      );
    }
    if (searching) {
      return const AppEmptyState(
        padding: pad,
        title: 'No matches',
        subtitle: 'Try another search.',
      );
    }
    if (query.favoritesOnly) {
      return const AppEmptyState(
        padding: pad,
        title: 'No favorites yet',
        subtitle: 'Bookmark a scan to save it here.',
      );
    }
    if (query.tag != null && query.tag!.isNotEmpty) {
      return const AppEmptyState(
        padding: pad,
        title: 'No scans with this tag',
        subtitle: 'Try another tag.',
      );
    }
    if (query.tagsPickerOpen) {
      return const AppEmptyState(
        padding: pad,
        title: 'No tagged scans',
        subtitle: 'Add a tag from ⋯ on a scan.',
      );
    }
    return const AppEmptyState(
      padding: pad,
      title: 'Nothing here yet',
      subtitle: 'Tap Scan to start.',
    );
  }
}

void _sortLibraryEntries(List<_ContinueEntry> entries, LibrarySort sort) {
  int cmp(_ContinueEntry a, _ContinueEntry b) {
    switch (sort) {
      case LibrarySort.recentlyModified:
        return b.sortAt.compareTo(a.sortAt);
      case LibrarySort.recentlyCreated:
        return b.createdAt.compareTo(a.createdAt);
      case LibrarySort.nameAsc:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case LibrarySort.nameDesc:
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case LibrarySort.pageCount:
        return b.pageCount.compareTo(a.pageCount);
      case LibrarySort.fileSize:
        return b.bytes.compareTo(a.bytes);
    }
  }

  entries.sort(cmp);
}

sealed class _ContinueEntry {
  DateTime get sortAt;
  DateTime get createdAt;
  String get name;
  int get pageCount;
  int get bytes;
}

class _ContinueDoc extends _ContinueEntry {
  _ContinueDoc(this.doc);
  final ScannedDocument doc;
  @override
  DateTime get sortAt => doc.updatedAt;
  @override
  DateTime get createdAt => doc.createdAt;
  @override
  String get name => doc.name;
  @override
  int get pageCount => doc.pageCount;
  @override
  int get bytes => doc.fileSizeBytes ?? 0;
}

class _ContinueConvert extends _ContinueEntry {
  _ContinueConvert(this.output);
  final ConvertOutput output;
  @override
  DateTime get sortAt => output.modifiedAt;
  @override
  DateTime get createdAt => output.modifiedAt;
  @override
  String get name => output.name;
  @override
  int get pageCount => 0;
  @override
  int get bytes => output.bytes;
}

class _ConvertContinueCard extends StatelessWidget {
  const _ConvertContinueCard({
    required this.output,
    required this.onOpen,
    required this.onMore,
    required this.onFavorite,
    this.tagDefs = const [],
  });

  final ConvertOutput output;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final VoidCallback onFavorite;
  final List<TagDef> tagDefs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = _friendlyDate(output.modifiedAt);
    final meta = [output.meta, date].join(' · ');
    final isImage = _isImage(output.name);
    final byId = {for (final t in tagDefs) t.id: t};

    return LibraryFileCard(
      name: output.name,
      meta: meta,
      onOpen: onOpen,
      onMore: onMore,
      isFavorite: output.isFavorite,
      onFavorite: onFavorite,
      tagChips: [
        for (final id in output.tags.take(2))
          MetaChip(
            label: byId[id]?.name ?? id,
            color: byId[id] != null ? Color(byId[id]!.color) : null,
          ),
      ],
      thumbnail: isImage
          ? Image.file(
              File(output.path),
              fit: BoxFit.cover,
              cacheWidth: 160,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            )
          : Center(
              child: Icon(
                Icons.swap_horiz_rounded,
                color: scheme.primary,
                size: 24,
              ),
            ),
    );
  }

  static bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  static String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Updated today';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Updated yesterday';
    }
    return 'Updated ${d.month}/${d.day}';
  }
}
