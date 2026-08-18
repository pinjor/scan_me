import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/convert_outputs_service.dart';
import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../converters/convert_result_panel.dart';
import '../converters/document_converter_service.dart';
import '../file_viewer/file_viewer_screen.dart';

/// One-file success uses [ConvertResultPanel]. Many files get a compact list.
class PdfToolsResultPanel extends ConsumerStatefulWidget {
  const PdfToolsResultPanel({super.key, required this.results});

  final List<ConvertResult> results;

  @override
  ConsumerState<PdfToolsResultPanel> createState() =>
      _PdfToolsResultPanelState();
}

class _PdfToolsResultPanelState extends ConsumerState<PdfToolsResultPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(convertOutputsProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    if (results.isEmpty) return const SizedBox.shrink();
    if (results.length == 1) {
      return ConvertResultPanel(result: results.first);
    }

    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
                child: Text(
                  'PDF created successfully',
                  style: text.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${results.length} files',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ...results.take(8).map((r) {
            final name = r.outputPath.split(Platform.pathSeparator).last;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => FileViewerScreen.open(
                context,
                r.outputPath,
                title: name,
              ),
            );
          }),
          if (results.length > 8)
            Text(
              '+ ${results.length - 8} more',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final first = results.first;
                    FileViewerScreen.open(
                      context,
                      first.outputPath,
                      title: first.outputPath.split(Platform.pathSeparator).last,
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    var saved = 0;
                    for (final r in results) {
                      final name =
                          r.outputPath.split(Platform.pathSeparator).last;
                      final where = await DeviceSaveService.saveFile(
                        sourcePath: r.outputPath,
                        displayName: name,
                      );
                      if (where != null) saved++;
                    }
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          saved == 0
                              ? 'Save cancelled'
                              : 'Saved $saved file${saved == 1 ? '' : 's'}',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await SharePlus.instance.share(
                      ShareParams(
                        files: [
                          for (final r in results)
                            XFile(
                              r.outputPath,
                              mimeType: r.mimeType,
                              name: r.outputPath
                                  .split(Platform.pathSeparator)
                                  .last,
                            ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
