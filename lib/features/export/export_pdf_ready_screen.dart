import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/watermarked_pages_scroll.dart';

/// After PDF export — vertical page scroll + same overlay stamp as Review.
class ExportPdfReadyScreen extends StatelessWidget {
  const ExportPdfReadyScreen({
    super.key,
    required this.path,
    required this.title,
    required this.previewPagePaths,
  });

  final String path;
  final String title;
  final List<String> previewPagePaths;

  Future<void> _download(BuildContext context) async {
    try {
      final where = await DeviceSaveService.saveFile(sourcePath: path);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(where == null ? 'Download cancelled' : 'Downloaded'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not download. Try again.')),
      );
    }
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(path, mimeType: 'application/pdf', name: p.basename(path)),
        ],
        subject: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pages = previewPagePaths;
    final hasPages = pages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (hasPages)
              Text(
                '${pages.length} page${pages.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FadeRiseIn(
              child: hasPages
                  ? WatermarkedPagesScroll(pagePaths: pages)
                  : const AppEmptyState(
                      title: 'PDF ready',
                      subtitle: 'Share or download your document below.',
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _download(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.primary,
                        minimumSize: const Size(48, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
