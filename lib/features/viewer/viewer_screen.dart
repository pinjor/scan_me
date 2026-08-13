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
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/apptriangle_watermark_overlay.dart';

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
  final _tagCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _tagCtrl.dispose();
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final doc = _doc;
    if (doc == null || _error != null || _pageController == null) {
      return Scaffold(
        appBar: AppBar(),
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
    final folders = ref.watch(foldersProvider).valueOrNull ?? const <DocFolder>[];
    final folderName = folders
        .where((f) => f.id == doc.folderId)
        .map((f) => f.name)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name),
        actions: [
          IconButton(
            tooltip: doc.isFavorite ? 'Unfavorite' : 'Mark important',
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
                doc.isFavorite ? Icons.star : Icons.star_outline,
                key: ValueKey(doc.isFavorite),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Print',
            onPressed: () => _print(doc),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(doc),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'rename':
                  await _rename(doc);
                case 'move':
                  await _moveFolder(doc, folders);
                case 'tags':
                  await _editTags(doc);
                case 'activity':
                  await _showActivity(doc);
                case 'delete':
                  await _delete(doc);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename')),
              const PopupMenuItem(value: 'move', child: Text('Move to folder')),
              const PopupMenuItem(value: 'tags', child: Text('Tags')),
              const PopupMenuItem(value: 'activity', child: Text('Activity')),
              const PopupMenuItem(value: 'delete', child: Text('Move to Trash')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (folderName != null || doc.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (folderName != null)
                    MetaChip(label: folderName),
                  for (final t in doc.tags) MetaChip(label: t),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: child,
                  ),
                  child: Row(
                    key: ValueKey(_index),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Page ${_index + 1} of ${doc.pages.length}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
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
          SnackBar(content: Text('Print failed: $e')),
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

  Future<void> _moveFolder(
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
              trailing: doc.folderId == f.id ? const Icon(Icons.check) : null,
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
    await _reloadMeta();
  }

  Future<void> _editTags(ScannedDocument doc) async {
    _tagCtrl.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tags', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in doc.tags)
                        InputChip(
                          label: Text(t),
                          onDeleted: () async {
                            await ref
                                .read(documentsProvider.notifier)
                                .removeTag(doc.id, t);
                            await _reloadMeta();
                            setModal(() {});
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tagCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Add tag (e.g. Education)',
                      suffixIcon: Icon(Icons.add),
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) async {
                      await ref
                          .read(documentsProvider.notifier)
                          .addTag(doc.id, v);
                      _tagCtrl.clear();
                      await _reloadMeta();
                      setModal(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(documentsProvider.notifier)
                          .addTag(doc.id, _tagCtrl.text);
                      _tagCtrl.clear();
                      await _reloadMeta();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Done'),
                  ),
                ],
              );
            },
          ),
        );
      },
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
          '“${doc.name}” moves to Trash. You can restore it later from the home Trash view.',
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
