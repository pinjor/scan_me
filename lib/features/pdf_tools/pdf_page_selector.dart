import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';

/// Shared PDF page grid: thumbnail · number · selected state · multi-select.
class PdfPageSelector extends StatelessWidget {
  const PdfPageSelector({
    super.key,
    required this.pageCount,
    required this.selected,
    required this.onChanged,
    this.thumbnails = const {},
    this.multi = true,
    this.previewIndex,
    this.onPreview,
  });

  final int pageCount;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final Map<int, Uint8List> thumbnails;
  final bool multi;
  final int? previewIndex;
  final ValueChanged<int>? onPreview;

  void _toggle(int i) {
    if (!multi) {
      onChanged({i});
      return;
    }
    final next = {...selected};
    if (next.contains(i)) {
      next.remove(i);
    } else {
      next.add(i);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (multi)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => onChanged(
                    {for (var i = 0; i < pageCount; i++) i},
                  ),
                  child: const Text('Select all'),
                ),
                TextButton(
                  onPressed: selected.isEmpty ? null : () => onChanged({}),
                  child: const Text('Clear'),
                ),
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      '${selected.length} selected',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pageCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, i) {
            final isOn = selected.contains(i);
            final isPreview = previewIndex == i;
            final thumb = thumbnails[i];
            return Semantics(
              button: true,
              selected: isOn,
              label: 'Page ${i + 1}',
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  onTap: () {
                    _toggle(i);
                    onPreview?.call(i);
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: isOn || isPreview
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: isOn ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (thumb != null)
                                  Image.memory(
                                    thumb,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  )
                                else
                                  Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                if (multi)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Icon(
                                      isOn
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      size: 22,
                                      color: isOn
                                          ? scheme.primary
                                          : scheme.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            '${i + 1}',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PdfPreviewPane extends StatelessWidget {
  const PdfPreviewPane({
    super.key,
    required this.pageNumber,
    this.bytes,
  });

  final int pageNumber;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 0.72,
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.contain)
                : Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 48,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(height: 8),
          Text('Page $pageNumber', style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}
