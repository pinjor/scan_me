import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/convert_outputs_service.dart';
import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../file_viewer/file_viewer_screen.dart';
import 'document_converter_service.dart';

/// Shared open / save / share strip after a convert or image tool finishes.
class ConvertResultPanel extends ConsumerStatefulWidget {
  const ConvertResultPanel({super.key, required this.result});

  final ConvertResult result;

  @override
  ConsumerState<ConvertResultPanel> createState() => _ConvertResultPanelState();
}

class _ConvertResultPanelState extends ConsumerState<ConvertResultPanel> {
  @override
  void initState() {
    super.initState();
    // Keep Dashboard Continue in sync when a convert finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(convertOutputsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = result.outputPath.split(Platform.pathSeparator).last;
    final sizeLabel = _friendlySize(result.outputPath);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.success,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ready to use', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        result.label,
                        ?sizeLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ResultAction(
                  icon: Icons.open_in_new_rounded,
                  label: 'Open',
                  emphasis: _ActionEmphasis.primary,
                  onTap: () => FileViewerScreen.open(
                    context,
                    result.outputPath,
                    title: name,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultAction(
                  icon: Icons.save_alt_rounded,
                  label: 'Save',
                  emphasis: _ActionEmphasis.secondary,
                  onTap: () async {
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
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ResultAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  emphasis: _ActionEmphasis.secondary,
                  onTap: () async {
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
                ),
              ),
            ],
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

enum _ActionEmphasis { primary, secondary }

class _ResultAction extends StatelessWidget {
  const _ResultAction({
    required this.icon,
    required this.label,
    required this.emphasis,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final _ActionEmphasis emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isPrimary = emphasis == _ActionEmphasis.primary;
    final bg = isPrimary
        ? scheme.primary
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final fg = isPrimary ? scheme.onPrimary : scheme.onSurface;
    final border = isPrimary
        ? null
        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: border,
          ),
          child: SizedBox(
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
