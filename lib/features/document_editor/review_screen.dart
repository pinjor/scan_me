import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../shared/models/scanned_document.dart';
import '../export/export_screen.dart';
import '../scanner/document_scanner_service.dart';
import '../../core/providers.dart';
import '../../shared/widgets/apptriangle_watermark_overlay.dart';
import 'editor_controller.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

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
        if (didPop) {
          // Leaving review without a saved meta.json → delete draft folder.
          ref.read(editorSessionProvider.notifier).discardUnsaved();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          'Page ${session.selectedIndex + 1} of ${session.pages.length}',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: session.isProcessing
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExportScreen(),
                        ),
                      );
                    },
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.45,
                      ),
                      // RotatedBox keeps hit-testing aligned (unlike Transform.rotate).
                      child: RotatedBox(
                        quarterTurns: (page.rotation ~/ 90) % 4,
                        child: PhotoView(
                          key: ValueKey(
                            '${page.id}_${page.displayPath}_${page.rotation}',
                          ),
                          imageProvider: FileImage(File(page.displayPath)),
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
              _ThumbnailStrip(
                pages: session.pages,
                selectedIndex: session.selectedIndex,
                onSelect: (i) =>
                    ref.read(editorSessionProvider.notifier).selectPage(i),
                onReorder: (oldI, newI) =>
                    ref.read(editorSessionProvider.notifier).reorder(oldI, newI),
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
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(session.processingLabel ?? 'Processing…'),
                      ],
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

  Future<void> _showFilterSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showModalBottomSheet<({PageFilter filter, bool all})>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Enhance page',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Color (as scanned)'),
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.original, all: false),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.contrast),
                title: const Text('Black & white'),
                subtitle: const Text('Clearer text, cleaner paper'),
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.blackAndWhite, all: false),
                ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Apply black & white to all'),
                onTap: () => Navigator.pop(
                  ctx,
                  (filter: PageFilter.blackAndWhite, all: true),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset all to color'),
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
        const SnackBar(content: Text('Cannot delete the only page.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this page?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(editorSessionProvider.notifier).deleteSelectedPage();
    }
  }

  Future<void> _showMore(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Retake all'),
              onTap: () {
                Navigator.pop(ctx);
                _retakeAll(context);
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
  });

  final List<ScannedPage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;

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
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: scheme.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
