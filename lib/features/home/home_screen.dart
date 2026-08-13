import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/scanned_document.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../scanner/document_scanner_service.dart';
import '../settings/settings_screen.dart';
import '../viewer/viewer_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ScanMe', style: text.headlineMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Documents on this device',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Recent',
                style: text.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: docs.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load your documents.\n$e',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return _EmptyState(onScan: () => _startScan(context, ref));
                  }
                  return RefreshIndicator(
                    color: AppTheme.navy,
                    onRefresh: () =>
                        ref.read(documentsProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = list[index];
                        return _ScanRow(
                          doc: doc,
                          onOpen: () => _open(context, doc),
                          onMore: () => _showActions(context, ref, doc),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startScan(context, ref),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('New scan'),
      ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final outcome = await ref.read(documentScannerProvider).scan();

    switch (outcome) {
      case ScanCancelled():
        return;
      case ScanError(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      case ScanSuccess(:final imagePaths):
        if (!context.mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        try {
          await ref
              .read(editorSessionProvider.notifier)
              .startFromScanPaths(imagePaths);
          if (context.mounted) navigator.pop(); // dismiss import spinner
          if (!context.mounted) return;
          await navigator.push(
            MaterialPageRoute(builder: (_) => const ReviewScreen()),
          );
        } catch (e) {
          if (context.mounted) navigator.pop();
          messenger.showSnackBar(
            SnackBar(content: Text('Could not import scan: $e')),
          );
        }
    }
  }

  void _open(BuildContext context, ScannedDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ViewerScreen(documentId: doc.id)),
    );
  }

  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    ScannedDocument doc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    doc.name,
                    style: Theme.of(ctx).textTheme.titleMedium,
                    maxLines: 1,
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
                    'Delete',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _delete(context, ref, doc);
                  },
                ),
              ],
            ),
          ),
        );
      },
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
          decoration: const InputDecoration(labelText: 'Name'),
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
          const SnackBar(content: Text('Nothing to share yet.')),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete “${doc.name}”?'),
        content: const Text(
          'This permanently removes the scan stored on this phone.',
        ),
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
      await ref.read(documentsProvider.notifier).delete(doc.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No documents yet',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Scan paperwork, receipts, or forms. Everything stays on your phone — no account needed.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined, size: 20),
              label: const Text('Scan a document'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanRow extends StatelessWidget {
  const _ScanRow({
    required this.doc,
    required this.onOpen,
    required this.onMore,
  });

  final ScannedDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = DateFormat('MMM d, yyyy').format(doc.updatedAt);
    final type = doc.pdfPath != null ? 'PDF' : 'Images';
    final size = doc.fileSizeBytes != null
        ? _formatBytes(doc.fileSizeBytes!)
        : null;
    final meta = [
      '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
      type,
      ?size,
      date,
    ].join('  ·  ');

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 52,
                  height: 68,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child:
                      doc.thumbnailPath != null &&
                          File(doc.thumbnailPath!).existsSync()
                      ? Image.file(
                          File(doc.thumbnailPath!),
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          Icons.insert_drive_file_outlined,
                          color: scheme.onSurfaceVariant,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMore,
                icon: Icon(
                  Icons.more_horiz,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
