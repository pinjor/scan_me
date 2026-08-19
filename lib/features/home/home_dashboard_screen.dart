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
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_screen.dart';
import '../converters/image_formats_hub_screen.dart';
import '../file_viewer/file_viewer_screen.dart';
import '../pdf_tools/pdf_tools_hub_screen.dart';
import '../qr/qr_reader_screen.dart';
import '../viewer/viewer_screen.dart';
import 'dashboard_tools.dart';
import 'home_flows.dart';
import 'library_actions.dart';
import 'library_filter_bar.dart';

/// Home: search · shortcut tiles · library list.
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

  void _runTool(DashboardToolId id) {
    final q = ref.read(libraryQueryProvider.notifier);
    if (kScanOnlySurface && !kScanSurfaceShortcutIds.contains(id)) return;
    switch (id) {
      case DashboardToolId.smartScan:
        HomeFlows.startScan(context);
      case DashboardToolId.pdfTools:
      case DashboardToolId.pdfToTxt:
      case DashboardToolId.pdfToDocx:
      case DashboardToolId.txtToPdf:
      case DashboardToolId.pptxToPdf:
      case DashboardToolId.docxToPdf:
      case DashboardToolId.xlsxToCsv:
      case DashboardToolId.xlsxToPdf:
      case DashboardToolId.imageFormats:
      case DashboardToolId.editImages:
        _openConvertTool(id);
      case DashboardToolId.importImages:
        HomeFlows.imagesToPdf(context, ref);
      case DashboardToolId.files:
        q.showAll();
      case DashboardToolId.tags:
        q.showTagsPicker();
      case DashboardToolId.favorites:
        q.showFavorites();
      case DashboardToolId.trash:
        q.setShowTrash(true);
      case DashboardToolId.qrReader:
        AppPageRoute.push(context, const QrReaderScreen());
    }
  }

  void _openConvertTool(DashboardToolId id) {
    final toolId = convertToolIdForDashboard(id);
    if (toolId == null) {
      widget.onOpenTools();
      return;
    }
    final page = switch (toolId) {
      ConvertToolId.imageFormats ||
      ConvertToolId.editImages => const ImageFormatsHubScreen(),
      ConvertToolId.pdfTools => const PdfToolsHubScreen(),
      _ => ConvertToolScreen(tool: convertToolMeta(toolId)!),
    };
    AppPageRoute.push(context, page);
  }

  Future<void> _showCustomizeTools(BuildContext context) async {
    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (ctx, ref, _) {
            final selected = ref.watch(dashboardToolsProvider).toSet();
            final scheme = Theme.of(ctx).colorScheme;
            final text = Theme.of(ctx).textTheme;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Shortcuts', style: text.titleLarge),
                        ),
                        TextButton(
                          onPressed: () async {
                            await ref
                                .read(dashboardToolsProvider.notifier)
                                .resetDefaults();
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Text(
                      kScanOnlySurface
                          ? 'Scan uses the camera button. Import photos into a scan from here.'
                          : 'Scan uses the camera button. Convert tab still has every tool.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final meta in visibleDashboardCatalog)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primary.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: scheme.primary,
                              child: Icon(meta.icon, size: 22),
                            ),
                            title: Text(meta.label),
                            trailing: Icon(
                              selected.contains(meta.id)
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: selected.contains(meta.id)
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            onTap: () async {
                              final n = ref.read(
                                dashboardToolsProvider.notifier,
                              );
                              if (selected.contains(meta.id)) {
                                await n.remove(meta.id);
                              } else {
                                await n.add(meta.id);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
              if (!query.showTrash)
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SectionHeader(
                    title: 'Shortcuts',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: _ShortcutGrid(
                    selected: visibleDashboardTools(
                      ref.watch(dashboardToolsProvider),
                    ),
                    onTool: _runTool,
                    onAdd: () => _showCustomizeTools(context),
                    onRemove: (id) =>
                        ref.read(dashboardToolsProvider.notifier).remove(id),
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
                    return SliverToBoxAdapter(
                      child: _libraryEmpty(
                        query: query,
                        searching: searching,
                        bottomClear: bottomClear,
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
    required double bottomClear,
  }) {
    final pad = EdgeInsets.fromLTRB(24, 20, 24, bottomClear);
    if (query.showTrash) {
      return AppEmptyState(
        padding: pad,
        centered: false,
        title: 'Nothing in Trash',
        subtitle:
            'Deleted documents appear here. You can restore them anytime before they are removed automatically.',
        primaryLabel: 'Back to library',
        onPrimary: () => ref.read(libraryQueryProvider.notifier).showAll(),
      );
    }
    if (searching) {
      return AppEmptyState(
        padding: pad,
        centered: false,
        title: 'No documents found',
        subtitle: 'Try another name or tag.',
      );
    }
    if (query.favoritesOnly) {
      return AppEmptyState(
        padding: pad,
        centered: false,
        title: 'No favorites yet',
        subtitle: 'Tap the bookmark on a file’s thumbnail.',
      );
    }
    if (query.tag != null && query.tag!.isNotEmpty) {
      return AppEmptyState(
        padding: pad,
        centered: false,
        title: 'No documents with this tag',
        subtitle: 'Try another tag or add one from ⋯.',
      );
    }
    return AppEmptyState(
      padding: pad,
      centered: false,
      title: 'Nothing here yet',
      subtitle: 'Scan or import — files show up here.',
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

/// Two-row 4-col shortcut grid. Labels wrap to two lines.
class _ShortcutGrid extends StatelessWidget {
  const _ShortcutGrid({
    required this.selected,
    required this.onTool,
    required this.onAdd,
    required this.onRemove,
  });

  final List<DashboardToolId> selected;
  final void Function(DashboardToolId id) onTool;
  final VoidCallback onAdd;
  final void Function(DashboardToolId id) onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      for (var i = 0; i < selected.length; i++) ...[
        () {
          final id = selected[i];
          final meta = metaForTool(id);
          if (meta == null) return const SizedBox.shrink();
          return FadeRiseIn(
            delay: Duration(milliseconds: 28 * i),
            offset: 10,
            scaleFrom: 0.94,
            child: _ShortcutTile(
              icon: meta.icon,
              label: meta.label,
              color: scheme.primary,
              onTap: () => onTool(id),
              onLongPress: () => onRemove(id),
            ),
          );
        }(),
      ],
      FadeRiseIn(
        delay: Duration(milliseconds: 28 * selected.length),
        offset: 10,
        scaleFrom: 0.94,
        child: _ShortcutTile(
          icon: Icons.add,
          label: 'Add',
          color: scheme.primary,
          dashed: true,
          onTap: onAdd,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileW = constraints.maxWidth / 4;
        return Wrap(
          runSpacing: 10,
          children: [
            for (final tile in tiles) SizedBox(width: tileW, child: tile),
          ],
        );
      },
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.onLongPress,
    this.dashed = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppTheme.radiusMd);

    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        scale: 0.94,
        borderRadius: radius,
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: 86,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: dashed
                        ? Colors.transparent
                        : color.withValues(alpha: 0.14),
                    borderRadius: radius,
                    border: dashed
                        ? Border.all(color: scheme.outlineVariant, width: 1.2)
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: dashed ? scheme.onSurfaceVariant : color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _twoLineLabel(label),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Split on first space so "PDF Tools" / "QR reader" sit on two lines.
  static String _twoLineLabel(String label) {
    final i = label.indexOf(' ');
    if (i <= 0) return label;
    return '${label.substring(0, i)}\n${label.substring(i + 1)}';
  }
}
