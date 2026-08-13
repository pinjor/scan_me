import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../shared/models/scanned_document.dart';
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
          ? 'Document not found'
          : (doc.pages.isEmpty ? 'This document has no pages' : null);
      if (doc != null && doc.pages.isNotEmpty) {
        _pageController = PageController(initialPage: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final doc = _doc;
    if (doc == null || _error != null || _pageController == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'Missing document')),
      );
    }

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
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoViewGallery.builder(
                  itemCount: doc.pages.length,
                  pageController: _pageController!,
                  onPageChanged: (i) => setState(() => _index = i),
                  backgroundDecoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  builder: (context, index) {
                    final page = doc.pages[index];
                    final file = File(page.displayPath);
                    if (!file.existsSync()) {
                      return PhotoViewGalleryPageOptions.customChild(
                        child: Center(
                          child: Text(
                            'Missing page file',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      );
                    }
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(file),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                      heroAttributes: PhotoViewHeroAttributes(tag: page.id),
                    );
                  },
                ),
                const ApptriangleWatermarkOverlay(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Page ${_index + 1} of ${doc.pages.length}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
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
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${doc.name}"?'),
        content: const Text('Locally stored scan will be removed.'),
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
    if (ok == true && mounted) {
      await ref.read(documentsProvider.notifier).delete(doc.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}
