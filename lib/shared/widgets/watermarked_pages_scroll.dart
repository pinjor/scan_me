import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/text_watermark.dart';
import '../../core/theme/app_theme.dart';
import 'app_ui.dart';

/// Vertical page list with the same on-page watermark overlay as Review.
class WatermarkedPagesScroll extends StatelessWidget {
  const WatermarkedPagesScroll({
    super.key,
    required this.pagePaths,
    this.padding = const EdgeInsets.fromLTRB(12, 10, 12, 20),
    this.pageSeparator = 14,
    this.backgroundColor,
  });

  final List<String> pagePaths;
  final EdgeInsets padding;
  final double pageSeparator;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.35);

    if (pagePaths.isEmpty) {
      return const AppEmptyState(
        title: 'No pages',
        subtitle: 'This document has nothing to preview.',
      );
    }

    return ColoredBox(
      color: bg,
      child: ListView.separated(
        padding: padding,
        itemCount: pagePaths.length,
        separatorBuilder: (context, index) => SizedBox(height: pageSeparator),
        itemBuilder: (context, index) {
          final file = File(pagePaths[index]);
          if (!file.existsSync()) {
            return const AppEmptyState(
              title: 'Page missing',
              subtitle: 'This preview could not be loaded.',
            );
          }
          return Material(
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            clipBehavior: Clip.antiAlias,
            color: scheme.surface,
            child: TextWatermark.pageImageFile(pagePaths[index]),
          );
        },
      ),
    );
  }
}
