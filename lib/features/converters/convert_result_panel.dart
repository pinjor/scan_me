import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../file_viewer/file_viewer_screen.dart';
import 'document_converter_service.dart';

/// Shared open / save / share strip after a convert or image tool finishes.
class ConvertResultPanel extends StatelessWidget {
  const ConvertResultPanel({super.key, required this.result});

  final ConvertResult result;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = result.outputPath.split(Platform.pathSeparator).last;
    final sizeLabel = _friendlySize(result.outputPath);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ready', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        result.label,
                        ?sizeLabel,
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => FileViewerScreen.open(
              context,
              result.outputPath,
              title: name,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () async {
              final where = await DeviceSaveService.saveFile(
                sourcePath: result.outputPath,
                displayName: name,
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    where == null ? 'Save cancelled' : 'Saved to device',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await SharePlus.instance.share(
                ShareParams(
                  files: [
                    XFile(
                      result.outputPath,
                      mimeType: result.mimeType,
                      name: name,
                    ),
                  ],
                  subject: name,
                ),
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String? _friendlySize(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(0)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return null;
    }
  }
}
