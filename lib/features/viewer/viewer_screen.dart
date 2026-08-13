import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
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
        _pageController = PageController(initialPage: 0);
      }
    });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.name),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () => _share(doc),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            tooltip: 'Rename',
            onPressed: () => _rename(doc),
            icon: const Icon(Icons.drive_file_rename_outline),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => _delete(doc),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                                style: Theme.of(context).textTheme.bodyLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }
                        return PhotoViewGalleryPageOptions(
                          imageProvider: FileImage(file),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 3,
                          heroAttributes:
                              PhotoViewHeroAttributes(tag: page.id),
                        );
                      },
                    ),
                    const ApptriangleWatermarkOverlay(),
                  ],
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
                child: Row(
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
        ],
      ),
    );
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
      setState(() => doc.name = name);
    }
  }

  Future<void> _delete(ScannedDocument doc) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete this document?',
      message:
          'This permanently removes “${doc.name}” from this phone. This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok && mounted) {
      await ref.read(documentsProvider.notifier).delete(doc.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
