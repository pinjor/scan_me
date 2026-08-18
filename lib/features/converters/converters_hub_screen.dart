import 'package:flutter/material.dart';

import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../pdf_tools/pdf_tools_hub_screen.dart';
import 'convert_catalog.dart';
import 'convert_tool_screen.dart';
import 'image_formats_hub_screen.dart';

/// Convert hub: documents · image formats (stacked) · edit images (stacked).
class ConvertersHubScreen extends StatelessWidget {
  const ConvertersHubScreen({super.key, this.embedded = false});

  /// When true (Convert tab), no AppBar — shell provides chrome.
  final bool embedded;

  void _open(BuildContext context, ConvertToolMeta tool) {
    final page = switch (tool.id) {
      ConvertToolId.imageFormats ||
      ConvertToolId.editImages => const ImageFormatsHubScreen(),
      ConvertToolId.pdfTools => const PdfToolsHubScreen(),
      _ => ConvertToolScreen(tool: tool),
    };
    AppPageRoute.push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final body = FadeRiseIn(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          if (embedded) ...[
            Text('Convert', style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Documents, images, and edits — all on this phone.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
          ],
          for (final section in kConvertSections) ...[
            _SectionHeader(title: section.title, blurb: section.blurb),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cross = constraints.maxWidth >= 400 ? 2 : 1;
                final tools = kConvertTools
                    .where((t) => t.section == section.id)
                    .toList();
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tools.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: cross == 1 ? 3.1 : 1.65,
                  ),
                  itemBuilder: (context, i) {
                    final tool = tools[i];
                    return _ToolTile(
                      tool: tool,
                      onTap: () => _open(context, tool),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );

    if (embedded) {
      return SafeArea(child: body);
    }
    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: const Text('Convert'),
      ),
      body: body,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.blurb});

  final String title;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleSmall),
        const SizedBox(height: 2),
        Text(
          blurb,
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.tool, required this.onTap});

  final ConvertToolMeta tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      elevated: true,
      bordered: false,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(tool.icon, size: 22, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(tool.title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  tool.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    );
  }
}
