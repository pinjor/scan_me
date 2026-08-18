import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';

/// Compact educational header for convert / image-tool pages.
class ConvertToolHero extends StatelessWidget {
  const ConvertToolHero({
    super.key,
    required this.tool,
    this.extra,
  });

  final ConvertToolMeta tool;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return FadeRiseIn(
      child: AppCard(
        elevated: false,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  foregroundColor: scheme.primary,
                  child: Icon(tool.icon, size: 22),
                ),
                const SizedBox(width: 12),
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
              ],
            ),
            if (tool.steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tool.steps
                    .asMap()
                    .entries
                    .map((e) => '${e.key + 1}. ${e.value}')
                    .join('  ·  '),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            if (extra != null) ...[
              const SizedBox(height: 10),
              extra!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Primary CTA styling shared across convert tools.
ButtonStyle convertPrimaryButtonStyle() => FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
    );

ButtonStyle convertOutlineButtonStyle() => OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
    );
