import 'package:flutter/material.dart';

import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_tool_chrome.dart';
import 'convert_tool_screen.dart';

/// Stacked list for image format converters (JPG / PNG / WebP / GIF / HEIC).
class ImageFormatsHubScreen extends StatelessWidget {
  const ImageFormatsHubScreen({super.key, this.initialPath});

  final String? initialPath;

  void _open(BuildContext context, ConvertToolMeta tool) {
    AppPageRoute.push(
      context,
      ConvertToolScreen(tool: tool, initialPath: initialPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = convertToolMeta(ConvertToolId.imageFormats)!;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
          Text('Choose a format', style: text.titleSmall),
          const SizedBox(height: 10),
          for (final tool in kImageFormatTools) ...[
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
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
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
