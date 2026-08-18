import 'package:flutter/material.dart';

import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_chrome.dart';
import 'pdf_compress_screen.dart';
import 'pdf_images_to_pdf_screen.dart';
import 'pdf_merge_screen.dart';
import 'pdf_pages_tool_screen.dart';
import 'pdf_tools_catalog.dart';

/// Convert → PDF Tools. Organize / convert / optimize.
class PdfToolsHubScreen extends StatelessWidget {
  const PdfToolsHubScreen({super.key, this.embedded = false});

  /// Nav slot — no AppBar back, pad for the shell bar.
  final bool embedded;

  void _open(BuildContext context, PdfToolMeta tool) {
    final page = switch (tool.id) {
      PdfToolId.merge => PdfMergeScreen(tool: tool),
      PdfToolId.compress => PdfCompressScreen(tool: tool),
      PdfToolId.imagesToPdf => PdfImagesToPdfScreen(tool: tool),
      _ => PdfPagesToolScreen(tool: tool),
    };
    AppPageRoute.push(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final body = ListView(
      padding: EdgeInsets.fromLTRB(16, 12, 16, embedded ? 100 : 32),
      children: [
        if (embedded) ...[
          Text('PDF Tools', style: text.headlineSmall),
          const SizedBox(height: 16),
        ],
        ConvertToolHero(tool: convertToolMeta(ConvertToolId.pdfTools)!),
        const SizedBox(height: 20),
        for (final group in kPdfToolGroups) ...[
          Text(group.title, style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            group.blurb,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          ...kPdfTools
              .where((t) => t.group == group.id)
              .map(
                (tool) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PdfToolTile(
                    tool: tool,
                    onTap: () => _open(context, tool),
                  ),
                ),
              ),
          const SizedBox(height: 12),
        ],
      ],
    );

    if (embedded) {
      return SafeArea(bottom: false, child: body);
    }
    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: const Text('PDF Tools'),
      ),
      body: body,
    );
  }
}

class _PdfToolTile extends StatelessWidget {
  const _PdfToolTile({required this.tool, required this.onTap});

  final PdfToolMeta tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      elevated: false,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.primary.withValues(alpha: 0.14),
            foregroundColor: scheme.primary,
            radius: 22,
            child: Icon(tool.icon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
