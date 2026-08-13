import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../shared/models/scanned_document.dart';
import '../../core/theme/app_theme.dart';
import '../export/export_screen.dart';
import '../scanner/document_scanner_service.dart';
import '../../core/providers.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/apptriangle_watermark_overlay.dart';
import 'editor_controller.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.discardOnPop = false});

  /// True when Review is the root of the draft flow (e.g. gallery → PDF).
  final bool discardOnPop;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    if (session == null || session.pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No pages to review.')),
      );
    }

    final page = session.selectedPage!;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.discardOnPop) {
          ref.read(editorSessionProvider.notifier).discardUnsaved();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review'),
            Text(
              'Page ${session.selectedIndex + 1} of ${session.pages.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: session.isProcessing
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExportScreen(),
                        ),
                      );
                    },
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          child: RotatedBox(
                            quarterTurns: (page.rotation ~/ 90) % 4,
                            child: PhotoView(
                              key: ValueKey(
                                '${page.id}_${page.displayPath}_${page.rotation}',
                              ),
                              imageProvider:
                                  FileImage(File(page.displayPath)),
                              backgroundDecoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 3,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const ApptriangleWatermarkOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
              _PageFilterBar(
                filter: page.selectedFilter,
                busy: session.isProcessing,
                onChanged: (filter) => _setPageFilter(context, filter),
              ),
              _ThumbnailStrip(
                pages: session.pages,
                selectedIndex: session.selectedIndex,
                onSelect: (i) =>
                    ref.read(editorSessionProvider.notifier).selectPage(i),
                onReorder: (oldI, newI) =>
                    ref.read(editorSessionProvider.notifier).reorder(oldI, newI),
                onAddPage: session.isProcessing
                    ? null
                    : () => _addPages(context),
              ),
              _EditToolbar(
                busy: session.isProcessing,
                onFilter: () => _showFilterSheet(context),
                onRotate: () =>
                    ref.read(editorSessionProvider.notifier).rotateSelected(),
                onRetake: () => _retakePage(context),
                onDelete: () => _confirmDeletePage(context),
                onMore: () => _showMore(context),
              ),
            ],
          ),
          if (session.isProcessing)
            LoadingOverlay(
              message: session.processingLabel ?? 'Enhancing document…',
            ),
        ],
      ),
    ),
    );
  }

  Future<void> _setPageFilter(BuildContext context, PageFilter filter) async {
    if (sessionBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(editorSessionProvider.notifier).applyFilter(
            filter,
            applyToAll: false,
          );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Filter failed: $e')));
    }
  }

  bool get sessionBusy =>
      ref.read(editorSessionProvider)?.isProcessing ?? false;

  Future<void> _showFilterSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showAppBottomSheet<({PageFilter filter, bool all})>(
      context: context,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text('Enhance', style: text.headlineSmall),
              ),
              _EnhanceOptionCard(
                icon: Icons.image_outlined,
                title: 'Original',
                subtitle: 'Keep colors as captured',
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.original, all: false),
                ),
              ),
              const SizedBox(height: 8),
              _EnhanceOptionCard(
                icon: Icons.contrast,
                title: 'Black & white',
                subtitle: 'Clearer text, cleaner paper',
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.blackAndWhite, all: false),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Apply to all pages',
                style: text.titleSmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              _EnhanceOptionCard(
                icon: Icons.done_all,
                title: 'Black & white on all',
                subtitle: 'Enhance every page the same way',
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.blackAndWhite, all: true),
                ),
              ),
              const SizedBox(height: 8),
              _EnhanceOptionCard(
                icon: Icons.restart_alt,
                title: 'Original on all',
                subtitle: 'Turn off black & white everywhere',
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.original, all: true),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    try {
      await ref.read(editorSessionProvider.notifier).applyFilter(
            choice.filter,
            applyToAll: choice.all,
          );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Filter failed: $e')));
    }
  }

  Future<void> _addPages(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ref.read(documentScannerProvider).scan();
    if (!mounted) return;
    switch (outcome) {
      case ScanCancelled():
        return;
      case ScanError(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case ScanSuccess(:final imagePaths):
        try {
          await ref
              .read(editorSessionProvider.notifier)
              .appendPagesFromScanPaths(imagePaths);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not add pages: $e')),
          );
        }
    }
  }

  Future<void> _retakePage(BuildContext context) async {
    final session = ref.read(editorSessionProvider);
    if (session == null) return;
    final index = session.selectedIndex;
    final messenger = ScaffoldMessenger.of(context);

    final outcome = await ref.read(documentScannerProvider).scan(pageLimit: 1);
    if (!mounted) return;
    switch (outcome) {
      case ScanCancelled():
        return;
      case ScanError(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case ScanSuccess(:final imagePaths):
        if (imagePaths.isEmpty) return;
        await ref
            .read(editorSessionProvider.notifier)
            .replacePageAt(index, imagePaths.first);
    }
  }

  Future<void> _retakeAll(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retake all pages?'),
        content: const Text(
          'Current captured pages will be discarded and the scanner will restart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retake all'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final outcome = await ref.read(documentScannerProvider).scan(pageLimit: 50);
    if (!mounted) return;
    switch (outcome) {
      case ScanCancelled():
        return;
      case ScanError(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
      case ScanSuccess(:final imagePaths):
        try {
          await ref
              .read(editorSessionProvider.notifier)
              .replaceAllFromScanPaths(imagePaths);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Could not import pages: $e')),
          );
        }
    }
  }

  Future<void> _confirmDeletePage(BuildContext context) async {
    final session = ref.read(editorSessionProvider);
    if (session == null) return;
    if (session.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one page in this document.'),
        ),
      );
      return;
    }
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete this page?',
      message: 'This page will be removed from your draft. You can add another later.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(editorSessionProvider.notifier).deleteSelectedPage();
    }
  }

  Future<void> _showMore(BuildContext context) async {
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Retake all pages'),
            subtitle: const Text('Discard current pages and scan again'),
            onTap: () {
              Navigator.pop(ctx);
              _retakeAll(context);
            },
          ),
        ],
      ),
    );
  }
}

class _EnhanceOptionCard extends StatelessWidget {
  const _EnhanceOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _PageFilterBar extends StatelessWidget {
  const _PageFilterBar({
    required this.filter,
    required this.busy,
    required this.onChanged,
  });

  final PageFilter filter;
  final bool busy;
  final ValueChanged<PageFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This page',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<PageFilter>(
              segments: const [
                ButtonSegment(
                  value: PageFilter.blackAndWhite,
                  label: Text('B&W'),
                  icon: Icon(Icons.contrast, size: 18),
                ),
                ButtonSegment(
                  value: PageFilter.original,
                  label: Text('Original'),
                  icon: Icon(Icons.image_outlined, size: 18),
                ),
              ],
              selected: {filter},
              onSelectionChanged: busy
                  ? null
                  : (next) {
                      if (next.isEmpty) return;
                      onChanged(next.first);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatelessWidget {
  const _ThumbnailStrip({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
    required this.onReorder,
    this.onAddPage,
  });

  final List<ScannedPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onAddPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 100,
        child: Row(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                itemCount: pages.length,
                onReorderItem: onReorder,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(6),
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final page = pages[index];
                  final selected = index == selectedIndex;
                  return Padding(
                    key: ValueKey(page.id),
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => onSelect(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? scheme.primary : scheme.outline,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: RotatedBox(
                            quarterTurns: (page.rotation ~/ 90) % 4,
                            child: Image.file(
                              File(page.displayPath),
                              fit: BoxFit.cover,
                              cacheWidth: 120,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Tooltip(
                message: 'Add page',
                child: InkWell(
                  onTap: onAddPage,
                  borderRadius: BorderRadius.circular(6),
                  child: Ink(
                    width: 52,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.outline),
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: Icon(
                      Icons.add,
                      color: onAddPage == null
                          ? scheme.onSurface.withValues(alpha: 0.38)
                          : scheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditToolbar extends StatelessWidget {
  const _EditToolbar({
    required this.busy,
    required this.onFilter,
    required this.onRotate,
    required this.onRetake,
    required this.onDelete,
    required this.onMore,
  });

  final bool busy;
  final VoidCallback onFilter;
  final VoidCallback onRotate;
  final VoidCallback onRetake;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Material(
          color: scheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Tool(
                  icon: Icons.tune,
                  label: 'Enhance',
                  onTap: busy ? null : onFilter,
                ),
                _Tool(
                  icon: Icons.rotate_90_degrees_ccw,
                  label: 'Rotate',
                  onTap: busy ? null : onRotate,
                ),
                _Tool(
                  icon: Icons.camera_alt_outlined,
                  label: 'Retake',
                  onTap: busy ? null : onRetake,
                ),
                _Tool(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onTap: busy ? null : onDelete,
                ),
                _Tool(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onTap: busy ? null : onMore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: enabled
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.38),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: enabled
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface.withValues(alpha: 0.38),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
