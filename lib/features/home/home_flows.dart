import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers.dart';
import '../../core/services/access_permission.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../scanner/document_scanner_service.dart';

/// Shared Home / shell entry points for scan + images→PDF.
abstract final class HomeFlows {
  HomeFlows._();

  /// ML Kit multi-page scanner (native Add page) → Review. No hub screen.
  static Future<void> startScan(BuildContext context, WidgetRef ref) async {
    if (!await AccessPermission.ensureCamera(context)) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final outcome =
        await ref.read(documentScannerProvider).scan(pageLimit: 50);
    if (!context.mounted) return;

    switch (outcome) {
      case ScanCancelled():
        return;
      case ScanError(:final message):
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      case ScanSuccess(:final imagePaths):
        if (imagePaths.isEmpty) return;
        // Opaque Review-shell so Home never shows through during prepare.
        navigator.push(
          AppPageRoute<void>(
            builder: (_) => const _PreparingPagesScreen(
              message: 'Opening pages…',
            ),
          ),
        );
        try {
          await ref
              .read(editorSessionProvider.notifier)
              .startFromScanPaths(imagePaths);
          if (!context.mounted) return;
          await navigator.pushReplacement(
            AppPageRoute(
              builder: (_) => const ReviewScreen(discardOnPop: true),
            ),
          );
        } catch (e) {
          if (context.mounted) navigator.pop();
          messenger.showSnackBar(
            SnackBar(content: Text('Could not open scan: $e')),
          );
        }
    }
  }

  static Future<void> imagesToPdf(BuildContext context, WidgetRef ref) async {
    if (!await AccessPermission.ensurePhotos(context)) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;

    if (!context.mounted) return;
    navigator.push(
      AppPageRoute<void>(
        builder: (_) => const _PreparingPagesScreen(
          message: 'Opening images…',
        ),
      ),
    );

    try {
      final paths = picked.map((x) => x.path).toList();
      await ref.read(editorSessionProvider.notifier).startFromScanPaths(paths);
      if (!context.mounted) return;
      await navigator.pushReplacement(
        AppPageRoute(builder: (_) => const ReviewScreen(discardOnPop: true)),
      );
    } catch (e) {
      if (context.mounted) navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import images: $e')),
      );
    }
  }
}

/// Full-screen gate that matches Review chrome (no Home bleed-through).
class _PreparingPagesScreen extends StatelessWidget {
  const _PreparingPagesScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Review'),
              Text(
                'Getting pages ready',
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: Center(
          child: FadeRiseIn(
            offset: 10,
            duration: AppMotion.quick,
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
              bordered: false,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: text.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This stays on your device',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
