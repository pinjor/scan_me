import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/document_card.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_screen.dart';
import '../converters/image_formats_hub_screen.dart';
import '../file_viewer/file_viewer_screen.dart';
import '../qr/qr_reader_screen.dart';
import '../viewer/viewer_screen.dart';
import 'dashboard_tools.dart';
import 'home_flows.dart';

/// Home: search · shortcut tiles · continue.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenFiles,
    required this.onOpenTools,
    this.isActive = true,
  });

  final VoidCallback onOpenFiles;
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

  void _runTool(DashboardToolId id) {
    final q = ref.read(libraryQueryProvider.notifier);
    switch (id) {
      case DashboardToolId.smartScan:
        HomeFlows.startScan(context);
      case DashboardToolId.pdfTools:
        widget.onOpenTools();
      case DashboardToolId.pdfToTxt:
      case DashboardToolId.pdfToDocx:
      case DashboardToolId.txtToPdf:
      case DashboardToolId.pptxToPdf:
      case DashboardToolId.docxToPdf:
      case DashboardToolId.xlsxToCsv:
      case DashboardToolId.xlsxToPdf:
      case DashboardToolId.imageFormats:
      case DashboardToolId.editImages:
        _openConvertTool(DashboardToolId.imageFormats);
      case DashboardToolId.importImages:
        HomeFlows.imagesToPdf(context, ref);
      case DashboardToolId.files:
        q.setShowTrash(false);
        q.setFavoritesOnly(false);
        q.setFolder(null);
        widget.onOpenFiles();
      case DashboardToolId.tags:
        q.setShowTrash(false);
        widget.onOpenFiles();
      case DashboardToolId.favorites:
        q.setShowTrash(false);
        q.setFavoritesOnly(true);
        widget.onOpenFiles();
      case DashboardToolId.trash:
        q.setShowTrash(true);
        widget.onOpenFiles();
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
      ConvertToolId.imageFormats || ConvertToolId.editImages =>
        const ImageFormatsHubScreen(),
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
                          child: Text(
                            'Shortcuts',
                            style: text.titleLarge,
                          ),
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
                      'Scan uses the camera button. Convert is in the Convert tab.',
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
                        for (final meta in kDashboardToolCatalog)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  meta.color.withValues(alpha: 0.14),
                              foregroundColor: meta.color,
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
                              final n =
                                  ref.read(dashboardToolsProvider.notifier);
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

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final convertsAsync = ref.watch(convertOutputsProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final search = ref.watch(libraryQueryProvider).search;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: GestureDetector(
        onTap: _dismissSearch,
        behavior: HitTestBehavior.deferToChild,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ScanMe', style: text.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            'Your documents, ready when you are.',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
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
                        ref
                            .read(themeModeProvider.notifier)
                            .setMode(next);
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
                  onChanged: (v) {
                    ref.read(libraryQueryProvider.notifier).setSearch(v);
                  },
                  onSubmitted: (_) {
                    _dismissSearch();
                    if (_searchCtrl.text.trim().isNotEmpty) {
                      widget.onOpenFiles();
                    }
                  },
                  onClear: () {
                    ref.read(libraryQueryProvider.notifier).setSearch('');
                    _dismissSearch();
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: SectionHeader(
                  title: 'Shortcuts',
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: _ShortcutGrid(
                  selected: sanitizeDashboardTools(
                    ref.watch(dashboardToolsProvider),
                  ),
                  onTool: _runTool,
                  onAdd: () => _showCustomizeTools(context),
                  onRemove: (id) =>
                      ref.read(dashboardToolsProvider.notifier).remove(id),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: SectionHeader(
                  title: 'Continue',
                  padding: EdgeInsets.zero,
                  trailing: TextButton(
                    onPressed: () {
                      ref
                          .read(libraryQueryProvider.notifier)
                          .setShowTrash(false);
                      ref
                          .read(libraryQueryProvider.notifier)
                          .setFavoritesOnly(false);
                      widget.onOpenFiles();
                    },
                    child: const Text('View all'),
                  ),
                ),
              ),
            ),
            docsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: SizedBox(
                  height: 420,
                  child: AppListSkeleton(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                final tagCatalog =
                    tagsAsync.valueOrNull ?? const <TagDef>[];
                final tagNamesById = {
                  for (final t in tagCatalog) t.id: t.name,
                };
                final searching = search.trim().isNotEmpty;
                final q = search.trim().toLowerCase();
                final docs = filterAndSortDocuments(
                  all,
                  LibraryQuery(
                    search: search,
                    sort: LibrarySort.recentlyModified,
                    favoritesFirst: false,
                  ),
                  tagNamesById: tagNamesById,
                );
                final converts = (convertsAsync.valueOrNull ?? const [])
                    .where(
                      (c) =>
                          !searching ||
                          c.name.toLowerCase().contains(q) ||
                          (c.kindLabel?.toLowerCase().contains(q) ?? false),
                    )
                    .toList();

                final entries = <_ContinueEntry>[
                  for (final d in docs) _ContinueDoc(d),
                  for (final c in converts) _ContinueConvert(c),
                ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));

                final recents =
                    entries.take(searching ? 20 : 8).toList();
                if (recents.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: searching
                        ? AppEmptyState(
                            padding:
                                const EdgeInsets.fromLTRB(24, 8, 24, 100),
                            title: 'No documents found',
                            subtitle: 'Try another name or tag.',
                            primaryLabel: 'Search all files',
                            primaryIcon: Icons.search,
                            onPrimary: widget.onOpenFiles,
                          )
                        : AppEmptyState(
                            padding:
                                const EdgeInsets.fromLTRB(24, 8, 24, 100),
                            title: 'Nothing here yet',
                            subtitle:
                                'Scans, imports, and converts show up under Continue.',
                          ),
                  );
                }
                final tagDefs = tagsAsync.valueOrNull ?? const <TagDef>[];
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: recents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = recents[index];
                      return FadeRiseIn(
                        child: switch (entry) {
                          _ContinueDoc(:final doc) => DocumentCard(
                              doc: doc,
                              tagDefs: tagDefs,
                              onOpen: () => AppPageRoute.push(
                                context,
                                ViewerScreen(documentId: doc.id),
                              ),
                              onMore: () =>
                                  _showQuickActions(context, doc),
                            ),
                          _ContinueConvert(:final output) =>
                            _ConvertContinueCard(
                              output: output,
                              onOpen: () => FileViewerScreen.open(
                                context,
                                output.path,
                                title: output.name,
                              ),
                              onMore: () =>
                                  _showConvertActions(context, output),
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
    );
  }

  Future<void> _showConvertActions(
    BuildContext context,
    ConvertOutput output,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              FileViewerScreen.open(
                context,
                output.path,
                title: output.name,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from converts'),
            onTap: () async {
              Navigator.pop(ctx);
              await ConvertOutputsService.delete(output.path);
              if (!mounted) return;
              await ref.read(convertOutputsProvider.notifier).refresh();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickActions(
    BuildContext context,
    ScannedDocument doc,
  ) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              AppPageRoute.push(
                context,
                ViewerScreen(documentId: doc.id),
              );
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
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('View all files'),
            onTap: () {
              Navigator.pop(ctx);
              widget.onOpenFiles();
            },
          ),
        ],
      ),
    );
  }
}

sealed class _ContinueEntry {
  DateTime get sortAt;
}

class _ContinueDoc extends _ContinueEntry {
  _ContinueDoc(this.doc);
  final ScannedDocument doc;
  @override
  DateTime get sortAt => doc.updatedAt;
}

class _ContinueConvert extends _ContinueEntry {
  _ContinueConvert(this.output);
  final ConvertOutput output;
  @override
  DateTime get sortAt => output.modifiedAt;
}

class _ConvertContinueCard extends StatelessWidget {
  const _ConvertContinueCard({
    required this.output,
    required this.onOpen,
    required this.onMore,
  });

  final ConvertOutput output;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = _friendlyDate(output.modifiedAt);
    final meta = [output.meta, date].join(' · ');
    final isImage = _isImage(output.name);

    return Semantics(
      button: true,
      label: '${output.name}, $meta',
      child: AppCard(
        onTap: onOpen,
        elevated: false,
        padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 56,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: isImage
                    ? Image.file(
                        File(output.path),
                        fit: BoxFit.cover,
                        cacheWidth: 160,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.swap_horiz_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 26,
                        ),
                      )
                    : Icon(
                        Icons.swap_horiz_rounded,
                        color: scheme.primary,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    output.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppCircleIconButton(
              icon: Icons.more_horiz,
              tooltip: 'More actions',
              size: AppTheme.tapMin,
              onPressed: onMore,
            ),
          ],
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

/// Non-scrollable 4-col shortcut tiles.
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
              color: meta.color,
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 4,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, i) => tiles[i],
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

    return Semantics(
      button: true,
      label: label,
      child: PressableScale(
        onTap: onTap,
        scale: 0.92,
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                painter: dashed
                    ? _DashedCirclePainter(color: scheme.outlineVariant)
                    : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: dashed
                        ? Colors.transparent
                        : color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: dashed ? scheme.onSurfaceVariant : color,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = Offset.zero & size;
    const dash = 4.0;
    const gap = 3.0;
    final path = Path()..addOval(rect.deflate(1));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
