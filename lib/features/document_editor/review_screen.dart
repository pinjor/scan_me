import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import '../../shared/models/scanned_document.dart';
import '../../core/theme/app_theme.dart';
import '../export/export_screen.dart';
import '../scanner/document_scanner_service.dart';
import '../../core/services/access_permission.dart';
import '../../core/providers.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
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
        appBar: AppBar(
          leading: scanMeAppBarLeading(context),
          title: const Text('Review'),
        ),
        body: AppEmptyState(
          title: 'No pages to review',
          subtitle: 'Go back and capture or import at least one page.',
          primaryLabel: Navigator.of(context).canPop() ? 'Go back' : null,
          primaryIcon: Icons.arrow_back,
          onPrimary: Navigator.of(context).canPop()
              ? () => Navigator.of(context).maybePop()
              : null,
        ),
      );
    }

    final page = session.selectedPage!;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !session.isProcessing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.discardOnPop) {
          ref.read(editorSessionProvider.notifier).discardUnsaved();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
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
                          AppPageRoute.push(context, const ExportScreen());
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
                                '${page.id}_${page.selectedFilter.wire}_'
                                '${page.displayPath}_${page.rotation}',
                              ),
                              imageProvider:
                                  FileImage(File(page.displayPath)),
                              backgroundDecoration: const BoxDecoration(
                                color: Colors.transparent,
                              ),
                              initialScale:
                                  PhotoViewComputedScale.contained,
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 3,
                              filterQuality: FilterQuality.high,
                              enableRotation: false,
                              gestureDetectorBehavior:
                                  HitTestBehavior.opaque,
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
                canDelete: session.pages.length > 1,
                onFilter: () => _showFilterSheet(context),
                onRotate: () =>
                    ref.read(editorSessionProvider.notifier).rotateSelected(),
                onRetake: () => _retakePage(context),
                onDelete: () => _confirmDeletePage(context),
                onRetakeAll: () => _retakeAll(context),
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not apply that look. Try again.'),
        ),
      );
    }
  }

  bool get sessionBusy =>
      ref.read(editorSessionProvider)?.isProcessing ?? false;

  Future<void> _showFilterSheet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final previewPath =
        ref.read(editorSessionProvider)?.selectedPage?.displayPath;
    final choice = await showAppBottomSheet<({PageFilter filter, bool all})>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        final scheme = Theme.of(ctx).colorScheme;
        const thisPage = [
          PageFilter.original,
          PageFilter.blackAndWhite,
          PageFilter.grayscale,
          PageFilter.autoEnhance,
          PageFilter.vivid,
          PageFilter.lighten,
        ];
        const allPages = [
          PageFilter.blackAndWhite,
          PageFilter.grayscale,
          PageFilter.autoEnhance,
          PageFilter.vivid,
          PageFilter.lighten,
          PageFilter.original,
        ];
        IconData iconFor(PageFilter f) => switch (f) {
              PageFilter.original => Icons.crop_original,
              PageFilter.blackAndWhite => Icons.contrast,
              PageFilter.grayscale => Icons.filter_b_and_w,
              PageFilter.autoEnhance => Icons.tonality,
              PageFilter.vivid => Icons.palette_outlined,
              PageFilter.lighten => Icons.wb_sunny_outlined,
            };
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text('Enhance', style: text.headlineSmall),
                ),
                Text(
                  'This page',
                  style: text.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final f in thisPage) ...[
                  _EnhanceOptionCard(
                    icon: iconFor(f),
                    title: f.enhanceTitle,
                    subtitle: f.description,
                    previewPath: previewPath,
                    grayscalePreview: f.previewAsGrey,
                    onTap: () => Navigator.pop(ctx, (filter: f, all: false)),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
                Text(
                  'All pages',
                  style: text.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                for (final f in allPages) ...[
                  _EnhanceOptionCard(
                    icon: f == PageFilter.original
                        ? Icons.restart_alt
                        : Icons.done_all,
                    title: f.enhanceTitle,
                    subtitle: f.description,
                    previewPath: previewPath,
                    grayscalePreview: f.previewAsGrey,
                    onTap: () => Navigator.pop(ctx, (filter: f, all: true)),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
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
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not apply that look. Try again.'),
        ),
      );
    }
  }

  Future<void> _addPages(BuildContext context) async {
    if (!await AccessPermission.ensureCamera(context)) return;
    if (!context.mounted) return;
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
    if (!await AccessPermission.ensureCamera(context)) return;
    if (!context.mounted) return;
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
    if (!await AccessPermission.ensureCamera(context)) return;
    if (!mounted) return;

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
}

class _EnhanceOptionCard extends StatelessWidget {
  const _EnhanceOptionCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.previewPath,
    this.grayscalePreview = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String? previewPath;
  final bool grayscalePreview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final path = previewPath;
    return AppCard(
      elevated: false,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Row(
        children: [
          if (path != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 48,
                child: ColorFiltered(
                  colorFilter: grayscalePreview
                      ? const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ])
                      : const ColorFilter.mode(
                          Colors.transparent,
                          BlendMode.dst,
                        ),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                  ),
                ),
              ),
            )
          else
            Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
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

  static const _quick = [
    PageFilter.blackAndWhite,
    PageFilter.grayscale,
    PageFilter.autoEnhance,
    PageFilter.vivid,
    PageFilter.lighten,
    PageFilter.original,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
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
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final f in _quick)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: filter == f,
                    onSelected: busy
                        ? null
                        : (_) {
                            // Always apply — even re-tap selected filter.
                            onChanged(f);
                          },
                  ),
              ],
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
                              key: ValueKey(
                                '${page.id}_${page.selectedFilter.wire}_'
                                '${page.displayPath}',
                              ),
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
    required this.canDelete,
    required this.onFilter,
    required this.onRotate,
    required this.onRetake,
    required this.onDelete,
    required this.onRetakeAll,
  });

  final bool busy;
  final bool canDelete;
  final VoidCallback onFilter;
  final VoidCallback onRotate;
  final VoidCallback onRetake;
  final VoidCallback onDelete;
  final VoidCallback onRetakeAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
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
                    icon: Icons.document_scanner_outlined,
                    label: 'Retake',
                    onTap: busy ? null : onRetake,
                  ),
                  _Tool(
                    icon: Icons.delete_outline,
                    label: 'Delete',
                    onTap: busy || !canDelete ? null : onDelete,
                  ),
                  _Tool(
                    icon: Icons.more_horiz,
                    label: 'More',
                    onTap: busy
                        ? null
                        : () => _showMore(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
            subtitle: const Text('Scan every page again'),
            onTap: () {
              Navigator.pop(ctx);
              onRetakeAll();
            },
          ),
        ],
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
    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 68,
          height: 68,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 24,
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
      ),
    );
  }
}
