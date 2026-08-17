import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/document_card.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../converters/converters_hub_screen.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_screen.dart';
import 'home_flows.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.embedded = false,
    this.onOpenTools,
    this.isActive = true,
  });

  /// Files tab inside [MainShellScreen] — no Settings push, no FAB.
  final bool embedded;
  final VoidCallback? onOpenTools;

  /// False when another shell tab is showing (KeepAlive still mounts this).
  final bool isActive;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  var _searchFocused = false;
  var _showTagsRow = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive && !widget.isActive) {
      _searchFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final query = ref.watch(libraryQueryProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
              child: Row(
                children: [
                  if (!widget.embedded && Navigator.of(context).canPop()) ...[
                    const AppBarBackButton(),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      query.showTrash
                          ? 'Recently deleted'
                          : (widget.embedded ? 'Files' : 'ScanMe'),
                      style: text.titleLarge,
                    ),
                  ),
                  AppCircleIconButton(
                    icon: query.showTrash
                        ? Icons.folder_outlined
                        : Icons.delete_outline,
                    tooltip: query.showTrash ? 'Library' : 'Trash',
                    size: 48,
                    onPressed: () {
                      ref
                          .read(libraryQueryProvider.notifier)
                          .setShowTrash(!query.showTrash);
                    },
                  ),
                  if (!widget.embedded)
                    AppCircleIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      size: 48,
                      onPressed: () {
                        AppPageRoute.push(context, const SettingsScreen());
                      },
                    ),
                ],
              ),
            ),
            if (query.showTrash)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                'Documents stay here until they\'re automatically removed.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!query.showTrash) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: AnimatedContainer(
                  duration: AppMotion.chip,
                  curve: AppMotion.emphasizedDecelerate,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    boxShadow: _searchFocused
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: AppSearchBar(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    dense: true,
                    onChanged: (v) =>
                        ref.read(libraryQueryProvider.notifier).setSearch(v),
                    onSubmitted: (_) => _searchFocus.unfocus(),
                    onClear: () {
                      ref.read(libraryQueryProvider.notifier).setSearch('');
                      _searchFocus.unfocus();
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: !query.favoritesOnly &&
                                query.tag == null,
                            onSelected: (_) {
                              final n =
                                  ref.read(libraryQueryProvider.notifier);
                              n.setFavoritesOnly(false);
                              n.setFolder(null);
                              n.setTag(null);
                              setState(() {
                                _showTagsRow = false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Favorites',
                            selected: query.favoritesOnly,
                            icon: query.favoritesOnly
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            onSelected: (v) => ref
                                .read(libraryQueryProvider.notifier)
                                .setFavoritesOnly(v),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Tags',
                            selected: _showTagsRow || query.tag != null,
                            onSelected: (_) {
                              setState(() {
                                _showTagsRow = !_showTagsRow;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<LibrarySort>(
                      tooltip: 'Sort',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.sort, size: 20),
                      initialValue: query.sort,
                      onSelected: (s) =>
                          ref.read(libraryQueryProvider.notifier).setSort(s),
                      itemBuilder: (_) => [
                        for (final s in LibrarySort.values)
                          CheckedPopupMenuItem(
                            value: s,
                            checked: query.sort == s,
                            child: Text(s.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: AppMotion.chip,
                curve: AppMotion.emphasizedDecelerate,
                alignment: Alignment.topCenter,
                child: _showTagsRow
                    ? docsAsync.maybeWhen(
                        data: (all) {
                          final catalog = ref.watch(tagsProvider).valueOrNull ??
                              const <TagDef>[];
                          final usedIds = collectAllTags(all);
                          final tags = catalog
                              .where((t) => usedIds.contains(t.id))
                              .toList();
                          if (tags.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                              child: Text(
                                'No tags on documents yet',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              height: 40,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                children: [
                                  for (final tag in tags) ...[
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      avatar: CircleAvatar(
                                        backgroundColor: Color(tag.color),
                                        radius: 7,
                                      ),
                                      label: Text(
                                        tag.name,
                                        style: TextStyle(
                                          color: query.tag == tag.id
                                              ? Colors.white
                                              : scheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      selectedColor: Color(tag.color),
                                      checkmarkColor: Colors.white,
                                      selected: query.tag == tag.id,
                                      onSelected: (sel) => ref
                                          .read(libraryQueryProvider.notifier)
                                          .setTag(sel ? tag.id : null),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            Expanded(
              child: AppBodySwitch(
                child: docsAsync.when(
                  loading: () => const KeyedSubtree(
                    key: ValueKey('home-loading'),
                    child: _HomeSkeleton(),
                  ),
                  error: (_, _) => KeyedSubtree(
                    key: const ValueKey('home-error'),
                    child: AppErrorState(
                      title: "Couldn't load documents",
                      subtitle: 'Check storage and try again.',
                      onRetry: () =>
                          ref.read(documentsProvider.notifier).refresh(),
                    ),
                  ),
                  data: (all) {
                    final tagCatalog = ref.watch(tagsProvider).valueOrNull ??
                        const <TagDef>[];
                    final tagNamesById = {
                      for (final t in tagCatalog) t.id: t.name,
                    };
                    final list = filterAndSortDocuments(
                      all,
                      query,
                      tagNamesById: tagNamesById,
                    );
                    if (list.isEmpty) {
                      return KeyedSubtree(
                        key: ValueKey(
                          query.showTrash ? 'home-trash-empty' : 'home-empty',
                        ),
                        child: AppEmptyState(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                          title: query.showTrash
                              ? 'Nothing in Trash'
                              : 'No documents yet',
                          subtitle: query.showTrash
                              ? 'Deleted documents appear here. You can restore them anytime before they are removed automatically.'
                              : 'Scan your first document or import images to create a PDF.',
                          primaryLabel: query.showTrash
                              ? 'Back to library'
                              : 'Scan Document',
                          onPrimary: query.showTrash
                              ? () => ref
                                  .read(libraryQueryProvider.notifier)
                                  .setShowTrash(false)
                              : () => _startScan(context, ref),
                          secondaryLabel:
                              query.showTrash ? null : 'Import Images',
                          onSecondary: query.showTrash
                              ? null
                              : () => _imagesToPdf(context, ref),
                          secondaryIcon: Icons.collections_outlined,
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey(
                        'home-list-${query.showTrash}-${list.length}',
                      ),
                      child: RefreshIndicator(
                        color: scheme.primary,
                        onRefresh: () async {
                          await ref.read(documentsProvider.notifier).refresh();
                          await ref.read(tagsProvider.notifier).refresh();
                        },
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            6,
                            12,
                            widget.embedded ? 110 : 100,
                          ),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final doc = list[index];
                            final tagDefs = ref
                                    .watch(tagsProvider)
                                    .valueOrNull ??
                                const <TagDef>[];
                            return StaggeredListItem(
                              index: index,
                              child: DocumentCard(
                                doc: doc,
                                tagDefs: tagDefs,
                                onOpen: () => _open(context, doc),
                                onMore: () => query.showTrash
                                    ? _showTrashActions(context, ref, doc)
                                    : _showActions(context, ref, doc),
                                onDelete: query.showTrash
                                    ? null
                                    : () => _delete(context, ref, doc),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: (widget.embedded || query.showTrash)
          ? null
          : ScanFabMenu(
              onScan: () => HomeFlows.startScan(context),
              onImagesToPdf: () => HomeFlows.imagesToPdf(context, ref),
              onConverters: () {
                if (widget.onOpenTools != null) {
                  widget.onOpenTools!();
                } else {
                  AppPageRoute.push(context, const ConvertersHubScreen());
                }
              },
            ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    await HomeFlows.startScan(context);
  }

  Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    await HomeFlows.imagesToPdf(context, ref);
  }

  void _open(BuildContext context, ScannedDocument doc) {
    AppPageRoute.push(context, ViewerScreen(documentId: doc.id));
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                doc.name,
                style: Theme.of(ctx).textTheme.titleLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(ctx);
                _open(context, doc);
              },
            ),
            ListTile(
              leading: Icon(
                doc.isFavorite ? Icons.bookmark : Icons.bookmark_border,
              ),
              title: Text(
                doc.isFavorite ? 'Remove from favorites' : 'Favorite',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(documentsProvider.notifier)
                    .setFavorite(doc.id, !doc.isFavorite);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer_outlined),
              title: const Text('Tags'),
              onTap: () async {
                Navigator.pop(ctx);
                await showDocumentTagsSheet(
                  context: context,
                  ref: ref,
                  doc: doc,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(ctx);
                await _rename(context, ref, doc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () async {
                Navigator.pop(ctx);
                await _share(context, doc);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Move to Trash',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _delete(context, ref, doc);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTrashActions(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore'),
            onTap: () async {
              Navigator.pop(ctx);
              await ref.read(documentsProvider.notifier).restore(doc.id);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete permanently',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showConfirmSheet(
                context: context,
                title: 'Delete permanently?',
                message:
                    '“${doc.name}” will be removed forever. This cannot be undone.',
                confirmLabel: 'Delete permanently',
              );
              if (ok) {
                await ref
                    .read(documentsProvider.notifier)
                    .permanentlyDelete(doc.id);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
  ) async {
    final controller = TextEditingController(text: doc.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Invoice March 2026',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(documentsProvider.notifier).rename(doc.id, name);
    }
  }

  Future<void> _share(BuildContext context, ScannedDocument doc) async {
    final paths = <String>[];
    if (doc.pdfPath != null && await File(doc.pdfPath!).exists()) {
      paths.add(doc.pdfPath!);
    } else {
      paths.addAll(doc.exportImagePaths.where((p) => File(p).existsSync()));
      if (paths.isEmpty) {
        for (final page in doc.pages) {
          if (File(page.displayPath).existsSync()) {
            paths.add(page.displayPath);
          }
        }
      }
    }
    if (paths.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nothing to share yet. Save the document first.'),
          ),
        );
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: paths.map((p) => XFile(p)).toList(),
        subject: doc.name,
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
  ) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Move to Trash?',
      message:
          '“${doc.name}” moves to Trash. You can restore it later, or it will be removed automatically after the trash period.',
      confirmLabel: 'Move to Trash',
    );
    if (ok) {
      await ref.read(documentsProvider.notifier).delete(doc.id);
    }
  }
}

/// Filter chip with forced white label on navy when selected (M3 contrast fix).
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? AppTheme.navyOnDark : AppTheme.navy;
    const onSel = Colors.white;
    final onUnsel = scheme.onSurface;
    return FilterChip(
      visualDensity: VisualDensity.compact,
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: fill,
      checkmarkColor: onSel,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      side: BorderSide(
        color: selected ? fill : scheme.outlineVariant,
      ),
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? onSel : onUnsel),
      label: Text(
        label,
        style: TextStyle(
          color: selected ? onSel : onUnsel,
          fontWeight: FontWeight.w600,
        ),
      ),
      labelStyle: TextStyle(
        color: selected ? onSel : onUnsel,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppListSkeleton();
  }
}
