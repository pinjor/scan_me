import 'package:flutter/material.dart';

import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_tool_chrome.dart';
import 'image_compress_tool_screen.dart';
import 'image_crop_tool_screen.dart';
import 'image_resize_tool_screen.dart';

/// Single entry for Crop · Resize · Compress (stacked list).
class ImageEditHubScreen extends StatelessWidget {
  const ImageEditHubScreen({super.key, this.initialPath});

  /// Prefill path when opened from Open-with without a specific edit action.
  final String? initialPath;

  void _open(BuildContext context, ConvertToolMeta tool) {
    final path = initialPath;
    final page = switch (tool.id) {
      ConvertToolId.crop => ImageCropToolScreen(initialPath: path),
      ConvertToolId.resize => ImageResizeToolScreen(initialPath: path),
      ConvertToolId.compress => ImageCompressToolScreen(initialPath: path),
      _ => throw StateError('Not an edit tool: ${tool.id}'),
    };
    AppPageRoute.push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final hub = convertToolMeta(ConvertToolId.editImages)!;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(hub.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ConvertToolHero(tool: hub),
          const SizedBox(height: 8),
          Text(
            'Choose what to do',
            style: text.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final tool in kEditImageTools) ...[
            AppCard(
              elevated: false,
              onTap: () => _open(context, tool),
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: tool.color.withValues(alpha: 0.14),
                    foregroundColor: tool.color,
                    child: Icon(tool.icon, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tool.title, style: text.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          tool.subtitle,
                          style: text.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
