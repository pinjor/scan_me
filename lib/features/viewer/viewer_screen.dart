import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/apptriangle_watermark_overlay.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../file_viewer/file_viewer_screen.dart';

class ViewerScreen extends ConsumerStatefulWidget {
  const ViewerScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  ScannedDocument? _doc;
  int _index = 0;
  bool _loading = true;
  String? _error;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await ref
        .read(documentStorageProvider)
        .loadDocument(widget.documentId);
    if (!mounted) return;
    setState(() {
      _doc = doc;
      _loading = false;
      _error = doc == null
          ? "We couldn't find this document. It may have been removed."
          : (doc.pages.isEmpty
              ? 'This document has no pages to show.'
              : null);
      if (doc != null && doc.pages.isNotEmpty) {
        _pageController ??= PageController(initialPage: 0);
      }
    });
  }

  Future<void> _reloadMeta() async {
    final doc = await ref
        .read(documentStorageProvider)
        .loadDocument(widget.documentId);
    if (!mounted || doc == null) return;
    setState(() => _doc = doc);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: scanMeAppBarLeading(context),
          title: const Text('Document'),
        ),
        body: const AppListSkeleton(),
      );
    }
    final doc = _doc;
    if (doc == null || _error != null || _pageController == null) {
      return Scaffold(
        appBar: AppBar(leading: scanMeAppBarLeading(context)),
        body: AppEmptyState(
          title: 'Document unavailable',
          subtitle: _error ?? "We couldn't open this file.",
          primaryLabel: 'Go back',
          primaryIcon: Icons.arrow_back,
          onPrimary: () => Navigator.of(context).pop(),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final tagsCatalog =
        ref.watch(tagsProvider).valueOrNull ?? const <TagDef>[];
    final tagById = {for (final t in tagsCatalog) t.id: t};

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(doc.name),
        actions: [
          IconButton(
            tooltip: doc.isFavorite ? 'Unfavorite' : 'Favorite',
            onPressed: () async {
              await ref
                  .read(documentsProvider.notifier)
                  .setFavorite(doc.id, !doc.isFavorite);
              await _reloadMeta();
            },
            icon: AnimatedSwitcher(
              duration: AppMotion.quick,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                doc.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                key: ValueKey(doc.isFavorite),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(doc),
            icon: const Icon(Icons.share_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) async {
              switch (v) {
                case 'print':
                  await _print(doc);
                case 'save':
                  await _saveToDevice(doc);
                case 'pdf':
                  final pdf = doc.pdfPath;
                  if (pdf != null && File(pdf).existsSync()) {
                    await FileViewerScreen.open(
                      context,
                      pdf,
                      title: '${doc.name}.pdf',
                    );
                  }
                case 'rename':
                  await _rename(doc);
                case 'tags':
                  await _editTags(doc);
                case 'activity':
                  await _showActivity(doc);
                case 'delete':
                  await _delete(doc);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'print', child: Text('Print')),
              const PopupMenuItem(value: 'save', child: Text('Save to device')),
              if (doc.pdfPath != null && File(doc.pdfPath!).existsSync())
                const PopupMenuItem(
                  value: 'pdf',
                  child: Text('View PDF'),
                ),
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'tags', child: Text('Tags')),
              const PopupMenuItem(value: 'activity', child: Text('Activity')),
              const PopupMenuItem(value: 'delete', child: Text('Move to Trash')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (doc.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in doc.tags)
                    MetaChip(
                      label: tagById[id]?.name ?? id,
                      color: tagById[id] != null
                          ? Color(tagById[id]!.color)
                          : null,
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: Hero(
                tag: 'doc-thumb-${doc.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PhotoViewGallery.builder(
                          itemCount: doc.pages.length,
                          pageController: _pageController!,
                          onPageChanged: (i) => setState(() => _index = i),
                          backgroundDecoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                          ),
                          builder: (context, index) {
                            final page = doc.pages[index];
                            final file = File(page.displayPath);
                            if (!file.existsSync()) {
                              return PhotoViewGalleryPageOptions.customChild(
                                child: Center(
                                  child: Text(
                                    "This page's image couldn't be found.",
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }
                            return PhotoViewGalleryPageOptions(
                              imageProvider: FileImage(file),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 3,
                            );
                          },
                        ),
                        const ApptriangleWatermarkOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: AppCard(
                elevated: false,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous page',
                      onPressed: _index <= 0
                          ? null
                          : () {
                              _pageController!.previousPage(
                                duration: AppMotion.quick,
                                curve: AppMotion.emphasizedDecelerate,
                              );
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.quick,
                        child: Text(
                          'Page ${_index + 1} of ${doc.pages.length}',
                          key: ValueKey(_index),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next page',
                      onPressed: _index >= doc.pages.length - 1
                          ? null
                          : () {
                              _pageController!.nextPage(
                                duration: AppMotion.quick,
                                curve: AppMotion.emphasizedDecelerate,
                              );
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _print(ScannedDocument doc) async {
    try {
      if (doc.pdfPath != null && File(doc.pdfPath!).existsSync()) {
        final bytes = await File(doc.pdfPath!).readAsBytes();
        await Printing.layoutPdf(
          name: doc.name,
          onLayout: (_) async => bytes,
        );
        return;
      }

      final paths = <String>[];
      for (final page in doc.pages) {
        if (File(page.displayPath).existsSync()) {
          paths.add(page.displayPath);
        }
      }
      if (paths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to print yet.')),
          );
        }
        return;
      }

      await Printing.layoutPdf(
        name: doc.name,
        onLayout: (format) async {
          final pdf = pw.Document();
          for (final path in paths) {
            final bytes = await File(path).readAsBytes();
            final image = pw.MemoryImage(bytes);
            pdf.addPage(
              pw.Page(
                pageFormat: format,
                build: (_) => pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),
            );
          }
          return pdf.save();
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong while printing. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _saveToDevice(ScannedDocument doc) async {
    final paths = <String>[];
    if (doc.pdfPath != null && File(doc.pdfPath!).existsSync()) {
      paths.add(doc.pdfPath!);
    }
    for (final p in doc.exportImagePaths) {
      if (File(p).existsSync()) paths.add(p);
    }
    if (paths.isEmpty &&
        doc.pdfPath == null &&
        doc.pages.isNotEmpty) {
      // No export yet — still allow saving current page display files.
      for (final page in doc.pages) {
        if (File(page.displayPath).existsSync()) {
          paths.add(page.displayPath);
        }
      }
    }
    if (paths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to save yet. Export a PDF first.')),
        );
      }
      return;
    }
    try {
      final saved = await DeviceSaveService.saveFiles(paths);
      if (!mounted) return;
      if (saved.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.length == 1
                ? 'Saved to device'
                : 'Saved ${saved.length} files to device',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong while saving. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _share(ScannedDocument doc) async {
    final paths = <String>[];
    if (doc.pdfPath != null && File(doc.pdfPath!).existsSync()) {
      paths.add(doc.pdfPath!);
    } else {
      for (final page in doc.pages) {
        if (File(page.displayPath).existsSync()) {
          paths.add(page.displayPath);
        }
      }
    }
    if (paths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to share yet.')),
        );
      }
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: paths.map(XFile.new).toList(), subject: doc.name),
    );
  }

  Future<void> _rename(ScannedDocument doc) async {
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
      await _reloadMeta();
    }
  }

  Future<void> _editTags(ScannedDocument doc) async {
    await showDocumentTagsSheet(
      context: context,
      ref: ref,
      doc: doc,
      onChanged: _reloadMeta,
    );
    await _reloadMeta();
  }

  Future<void> _showActivity(ScannedDocument doc) async {
    final fmt = DateFormat('d MMM yyyy');
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 20),
            _ActivityTimeline(
              events: [
                (label: 'Created', value: fmt.format(doc.createdAt)),
                (label: 'Modified', value: fmt.format(doc.updatedAt)),
                (
                  label: 'Exported',
                  value: doc.exportedAt != null
                      ? fmt.format(doc.exportedAt!)
                      : 'Not exported yet',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(ScannedDocument doc) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Move to Trash?',
      message:
          '“${doc.name}” moves to Trash. You can restore it later.',
      confirmLabel: 'Move to Trash',
    );
    if (ok && mounted) {
      await ref.read(documentsProvider.notifier).delete(doc.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _ActivityTimeline extends StatelessWidget {
  const _ActivityTimeline({required this.events});

  final List<({String label, String value})> events;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primaryContainer,
                            width: 2,
                          ),
                        ),
                      ),
                      if (i < events.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i < events.length - 1 ? 20 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].label, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          events[i].value,
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
