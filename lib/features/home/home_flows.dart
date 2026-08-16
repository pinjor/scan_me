import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../scanner/scan_capture_screen.dart';

/// Shared Home / shell entry points for scan + images→PDF.
abstract final class HomeFlows {
  HomeFlows._();

  static Future<void> startScan(BuildContext context) async {
    await AppPageRoute.push(context, const ScanCaptureScreen());
  }

  static Future<void> imagesToPdf(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
        AppPageRoute(
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
}
