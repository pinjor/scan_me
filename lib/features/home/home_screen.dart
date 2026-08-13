import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/document_card.dart';
import '../converters/converters_hub_screen.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../scanner/scan_capture_screen.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  var _searchFocused = false;
  var _showFoldersRow = false;
  var _showTagsRow = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      setState(() => _searchFocused = _searchFocus.hasFocus);
    });
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
    final foldersAsync = ref.watch(foldersProvider);
    final query = ref.watch(libraryQueryProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      query.showTrash ? 'Trash' : 'ScanMe',
                      style: text.titleLarge,
                    ),
                  ),
                  AppCircleIconButton(
                    icon: query.showTrash
                        ? Icons.folder_outlined
                        : Icons.delete_outline,
                    tooltip: query.showTrash ? 'Library' : 'Trash',
                    size: 40,
                    onPressed: () {
                      ref
                          .read(libraryQueryProvider.notifier)
                          .setShowTrash(!query.showTrash);
                    },
                  ),
                  AppCircleIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    size: 40,
                    onPressed: () {
                      AppPageRoute.push(context, const SettingsScreen());
                    },
                  ),
                ],
              ),
            ),
            if (!query.showTrash) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                child: AnimatedContainer(
                  duration: AppMotion.chip,
                  curve: Curves.easeOutCubic,
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
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    style: text.bodyMedium,
                    onChanged: (v) =>
                        ref.read(libraryQueryProvider.notifier).setSearch(v),
                    decoration: InputDecoration(
                      hintText: 'Search…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      suffixIcon: query.search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                ref
                                    .read(libraryQueryProvider.notifier)
                                    .setSearch('');
                              },
                            ),
                    ),
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
                            selected: !query.unfiledOnly &&
                                query.folderId == null &&
                                !query.favoritesOnly &&
                                query.tag == null,
                            onSelected: (_) {
                              final n =
                                  ref.read(libraryQueryProvider.notifier);
                              n.setFavoritesOnly(false);
                              n.setFolder(null);
                              n.setTag(null);
                              setState(() {
                                _showFoldersRow = false;
                                _showTagsRow = false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Favorites',
                            selected: query.favoritesOnly,
                            icon: query.favoritesOnly
                                ? Icons.star
                                : Icons.star_outline,
                            onSelected: (v) => ref
                                .read(libraryQueryProvider.notifier)
                                .setFavoritesOnly(v),
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Folders',
                            selected:
                                _showFoldersRow || query.folderId != null,
                            onSelected: (_) {
                              setState(() {
                                _showFoldersRow = !_showFoldersRow;
                                if (_showFoldersRow) _showTagsRow = false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Tags',
                            selected: _showTagsRow || query.tag != null,
                            onSelected: (_) {
                              setState(() {
                                _showTagsRow = !_showTagsRow;
                                if (_showTagsRow) _showFoldersRow = false;
                              });
                            },
                          ),
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: 'Unfiled',
                            selected: query.unfiledOnly,
                            onSelected: (_) => ref
                                .read(libraryQueryProvider.notifier)
                                .setFolder(null, unfiled: true),
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
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _showFoldersRow
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              ...foldersAsync.maybeWhen(
                                data: (folders) => [
                                  for (final f in folders) ...[
                                    GestureDetector(
                                      onLongPress: () =>
                                          _folderActions(context, ref, f),
                                      child: _FilterChip(
                                        label: f.name,
                                        selected: query.folderId == f.id,
                                        onSelected: (_) => ref
                                            .read(
                                                libraryQueryProvider.notifier)
                                            .setFolder(f.id),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.create_new_folder_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('New'),
                                    onPressed: () =>
                                        _createFolder(context, ref),
                                  ),
                                ],
                                orElse: () => const <Widget>[],
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              AnimatedSize(
                duration: AppMotion.chip,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _showTagsRow
                    ? docsAsync.maybeWhen(
                        data: (all) {
                          final tags = collectAllTags(all).toList()
                            ..sort(
                              (a, b) =>
                                  a.toLowerCase().compareTo(b.toLowerCase()),
                            );
                          if (tags.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                              child: Text(
                                'No tags yet',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              height: 36,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                children: [
                                  for (final tag in tags) ...[
                                    ChoiceChip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        tag,
                                        style: TextStyle(
                                          color: query.tag == tag
                                              ? Colors.white
                                              : null,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      labelStyle: TextStyle(
                                        color: query.tag == tag
                                            ? Colors.white
                                            : scheme.onSurface,
                                      ),
                                      selectedColor: AppTheme.navy,
                                      checkmarkColor: Colors.white,
                                      selected: query.tag == tag,
                                      onSelected: (sel) => ref
                                          .read(libraryQueryProvider.notifier)
                                          .setTag(sel ? tag : null),
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
                    child: AppEmptyState(
                      title: "Couldn't load documents",
                      subtitle: 'Pull to try again.',
                      primaryLabel: 'Try again',
                      primaryIcon: Icons.refresh,
                      onPrimary: () =>
                          ref.read(documentsProvider.notifier).refresh(),
                    ),
                  ),
                  data: (all) {
                    final list = filterAndSortDocuments(all, query);
                    final folders =
                        foldersAsync.valueOrNull ?? const <DocFolder>[];
                    if (list.isEmpty) {
                      return KeyedSubtree(
                        key: ValueKey(
                          query.showTrash ? 'home-trash-empty' : 'home-empty',
                        ),
                        child: AppEmptyState(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                          title: query.showTrash
                              ? 'Trash is empty'
                              : 'No documents yet',
                          subtitle: '',
                          primaryLabel: query.showTrash
                              ? 'Back to library'
                              : 'Scan Document',
                          onPrimary: query.showTrash
                              ? () => ref
                                  .read(libraryQueryProvider.notifier)
                                  .setShowTrash(false)
                              : () => _startScan(context, ref),
                          secondaryLabel:
                              query.showTrash ? null : 'Images to PDF',
                          onSecondary: query.showTrash
                              ? null
                              : () => _imagesToPdf(context, ref),
                          secondaryIcon: Icons.photo_library_outlined,
                        ),
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey(
                        'home-list-${query.showTrash}-${list.length}',
                      ),
                      child: RefreshIndicator(
                        color: AppTheme.navy,
                        onRefresh: () async {
                          await ref.read(documentsProvider.notifier).refresh();
                          await ref.read(foldersProvider.notifier).refresh();
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 100),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final doc = list[index];
                            final folderName = folders
                                .where((f) => f.id == doc.folderId)
                                .map((f) => f.name)
                                .firstOrNull;
                            return StaggeredListItem(
                              index: index,
                              child: DocumentCard(
                                doc: doc,
                                folderName: folderName,
                                onOpen: () => _open(context, doc),
                                onMore: () => query.showTrash
                                    ? _showTrashActions(context, ref, doc)
                                    : _showActions(
                                        context, ref, doc, folders),
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
      floatingActionButton: query.showTrash
          ? null
          : ScanFabMenu(
              onScan: () => _startScan(context, ref),
              onImagesToPdf: () => _imagesToPdf(context, ref),
              onConverters: () {
                AppPageRoute.push(context, const ConvertersHubScreen());
              },
            ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    await AppPageRoute.push(context, const ScanCaptureScreen());
  }

  Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: LoadingOverlay(message: 'Preparing images…'),
      ),
    );

    try {
      final paths = picked.map((x) => x.path).toList();
      await ref.read(editorSessionProvider.notifier).startFromScanPaths(paths);
      if (context.mounted) navigator.pop();
      if (!context.mounted) return;
      await navigator.push(
        AppPageRoute(
          builder: (_) => const ReviewScreen(discardOnPop: true),
        ),
      );
    } catch (e) {
      if (context.mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import images: $e')),
      );
    }
  }

  void _open(BuildContext context, ScannedDocument doc) {
    AppPageRoute.push(context, ViewerScreen(documentId: doc.id));
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Work'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(foldersProvider.notifier).create(name);
    }
  }

  Future<void> _folderActions(
    BuildContext context,
    WidgetRef ref,
    DocFolder folder,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename folder'),
            onTap: () async {
              Navigator.pop(ctx);
              final controller = TextEditingController(text: folder.name);
              final name = await showDialog<String>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Rename folder'),
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(d, controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              controller.dispose();
              if (name != null && name.isNotEmpty) {
                await ref.read(foldersProvider.notifier).rename(folder.id, name);
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete folder',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showConfirmSheet(
                context: context,
                title: 'Delete folder “${folder.name}”?',
                message:
                    'Documents in this folder become Unfiled. Files are not deleted.',
                confirmLabel: 'Delete folder',
              );
              if (ok) {
                await ref.read(foldersProvider.notifier).delete(folder.id);
                final q = ref.read(libraryQueryProvider);
                if (q.folderId == folder.id) {
                  ref.read(libraryQueryProvider.notifier).setFolder(null);
                }
                await ref.read(documentsProvider.notifier).refresh();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
    List<DocFolder> folders,
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
                doc.isFavorite ? Icons.star : Icons.star_outline,
              ),
              title: Text(
                doc.isFavorite ? 'Remove from favorites' : 'Mark important',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await ref
                    .read(documentsProvider.notifier)
                    .setFavorite(doc.id, !doc.isFavorite);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move to folder'),
              onTap: () async {
                Navigator.pop(ctx);
                await _moveToFolder(context, ref, doc, folders);
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
              leading: const Icon(Icons.ios_share_outlined),
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
                    '“${doc.name}” will be removed from this phone forever.',
                confirmLabel: 'Delete forever',
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

  Future<void> _moveToFolder(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
    List<DocFolder> folders,
  ) async {
    final chosen = await showAppBottomSheet<String?>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Unfiled'),
            onTap: () => Navigator.pop(ctx, ''),
          ),
          for (final f in folders)
            ListTile(
              title: Text(f.name),
              trailing: doc.folderId == f.id
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(ctx, f.id),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(documentsProvider.notifier).setFolder(
          doc.id,
          chosen.isEmpty ? null : chosen,
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
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}
