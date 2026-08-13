import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/document_card.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../scanner/scan_capture_screen.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.document_scanner,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ScanMe', style: text.headlineMedium),
                        const SizedBox(height: 2),
                        Text(
                          'Your documents, stored privately on this device',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppCircleIconButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Text(
                'Recent',
                style: text.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Expanded(
              child: docs.when(
                loading: () => const _HomeSkeleton(),
                error: (_, _) => AppEmptyState(
                  title: "Couldn't load documents",
                  subtitle:
                      'Something went wrong reading your local files. Pull to try again.',
                  primaryLabel: 'Try again',
                  primaryIcon: Icons.refresh,
                  onPrimary: () =>
                      ref.read(documentsProvider.notifier).refresh(),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return AppEmptyState(
                      title: 'No documents yet',
                      subtitle:
                          'Scan papers or convert photos into PDFs. Everything stays on your device.',
                      primaryLabel: 'Scan Document',
                      onPrimary: () => _startScan(context, ref),
                      secondaryLabel: 'Create PDF',
                      onSecondary: () => _imagesToPdf(context, ref),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.navy,
                    onRefresh: () =>
                        ref.read(documentsProvider.notifier).refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = list[index];
                        return DocumentCard(
                          doc: doc,
                          onOpen: () => _open(context, doc),
                          onMore: () => _showActions(context, ref, doc),
                          onDelete: () => _delete(context, ref, doc),
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
      floatingActionButton: ScanFabMenu(
        onScan: () => _startScan(context, ref),
        onImagesToPdf: () => _imagesToPdf(context, ref),
      ),
    );
  }

  Future<void> _startScan(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanCaptureScreen()),
    );
  }

  Future<void> _imagesToPdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: LoadingOverlay(message: 'Preparing images…'),
      ),
    );

    try {
      final paths = picked.map((x) => x.path).toList();
      await ref.read(editorSessionProvider.notifier).startFromScanPaths(paths);
      if (context.mounted) navigator.pop();
      if (!context.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const ReviewScreen(discardOnPop: true),
        ),
      );
    } catch (e) {
      if (context.mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import images: $e')),
      );
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
    await showAppBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text(
                doc.name,
                style: Theme.of(ctx).textTheme.titleLarge,
                maxLines: 2,
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _delete(context, ref, doc);
              },
            ),
          ],
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
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
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
          const SnackBar(
            content: Text('Nothing to share yet. Save the document first.'),
          ),
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
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete this document?',
      message: 'This permanently removes “${doc.name}” from this phone. '
          'This action cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (ok) {
      await ref.read(documentsProvider.notifier).delete(doc.id);
    }
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 112,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }
}
