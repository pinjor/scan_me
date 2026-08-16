import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/document_card.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../viewer/viewer_screen.dart';
import 'dashboard_tools.dart';
import 'home_flows.dart';

/// CamScanner-inspired Home: search · tools grid · recents.
class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onOpenFiles,
    required this.onOpenTools,
    this.onOpenSettings,
    this.isActive = true,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenTools;
  final VoidCallback? onOpenSettings;

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
      case DashboardToolId.pdfToTxt:
      case DashboardToolId.txtToPdf:
      case DashboardToolId.pptxToPdf:
      case DashboardToolId.pngToJpg:
      case DashboardToolId.jpgToPng:
        widget.onOpenTools();
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
    }
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
                            'Dashboard tools',
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
                      'Tap to add or remove. Long-press a home tile to remove.',
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      style: text.bodyMedium,
                      textInputAction: TextInputAction.search,
                      onChanged: (v) {
                        // Stay on Home while typing — only update query.
                        ref.read(libraryQueryProvider.notifier).setSearch(v);
                      },
                      onSubmitted: (_) {
                        _dismissSearch();
                        // Full library results live on Files.
                        if (_searchCtrl.text.trim().isNotEmpty) {
                          widget.onOpenFiles();
                        }
                      },
                      onTapOutside: (_) => _dismissSearch(),
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: const Icon(Icons.search, size: 22),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: search.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear',
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                      .read(libraryQueryProvider.notifier)
                                      .setSearch('');
                                  _dismissSearch();
                                },
                              ),
                      ),
                    ),
                  ),
                  if (widget.onOpenSettings != null) ...[
                    const SizedBox(width: 8),
                    AppCircleIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      size: 44,
                      onPressed: () => widget.onOpenSettings!(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
              child: _ToolsGrid(
                selected: ref.watch(dashboardToolsProvider),
                onTool: _runTool,
                onAdd: () => _showCustomizeTools(context),
                onRemove: (id) =>
                    ref.read(dashboardToolsProvider.notifier).remove(id),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Recents', style: text.titleMedium),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(libraryQueryProvider.notifier).setShowTrash(false);
                      ref.read(libraryQueryProvider.notifier).setFavoritesOnly(false);
                      widget.onOpenFiles();
                    },
                    child: const Text('View all'),
                  ),
                ],
              ),
            ),
          ),
          docsAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                title: "Couldn't load documents",
                subtitle: '',
                primaryLabel: 'Try again',
                primaryIcon: Icons.refresh,
                onPrimary: () =>
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
              final recents = filterAndSortDocuments(
                all,
                LibraryQuery(
                  search: search,
                  sort: LibrarySort.recentlyModified,
                  favoritesFirst: false,
                ),
                tagNamesById: tagNamesById,
              ).take(searching ? 20 : 8).toList();
              if (recents.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                    title: searching ? 'No matches' : 'No documents yet',
                    subtitle: searching
                        ? 'Try another name, or search all files.'
                        : '',
                    primaryLabel:
                        searching ? 'Search all files' : 'Scan Document',
                    onPrimary: searching
                        ? widget.onOpenFiles
                        : () => HomeFlows.startScan(context),
                    secondaryLabel: searching ? null : 'Import images',
                    onSecondary: searching
                        ? null
                        : () => HomeFlows.imagesToPdf(context, ref),
                          secondaryIcon: Icons.collections_outlined,
                  ),
                );
              }
              final tagDefs = tagsAsync.valueOrNull ?? const <TagDef>[];
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                sliver: SliverList.separated(
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final doc = recents[index];
                    return FadeRiseIn(
                      child: DocumentCard(
                        doc: doc,
                        tagDefs: tagDefs,
                        onOpen: () => AppPageRoute.push(
                          context,
                          ViewerScreen(documentId: doc.id),
                        ),
                        onMore: () => _showQuickActions(context, doc),
                      ),
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

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({
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
            delay: Duration(milliseconds: 30 * i),
            offset: 10,
            scaleFrom: 0.92,
            child: _ToolTile(
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
        delay: Duration(milliseconds: 30 * selected.length),
        offset: 10,
        scaleFrom: 0.92,
        child: _ToolTile(
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
        mainAxisSpacing: 12,
        crossAxisSpacing: 4,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, i) => tiles[i],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
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
    return PressableScale(
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
                  ? _DashedCirclePainter(
                      color: scheme.outlineVariant,
                    )
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
