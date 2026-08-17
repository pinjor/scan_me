import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_transitions.dart';

/// Primary / secondary / text actions with 48+ touch targets.
class AppButton extends StatelessWidget {
  const AppButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : _variant = _Variant.filled;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : _variant = _Variant.outlined;

  /// Secondary action (outlined) — preferred name for hierarchy.
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : _variant = _Variant.outlined;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  }) : _variant = _Variant.text;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(label),
            ],
          );

    final button = switch (_variant) {
      _Variant.filled => FilledButton(
          onPressed: onPressed,
          child: child,
        ),
      _Variant.outlined => OutlinedButton(
          onPressed: onPressed,
          child: child,
        ),
      _Variant.text => TextButton(
          onPressed: onPressed,
          child: child,
        ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

enum _Variant { filled, outlined, text }

/// Soft surface card with optional border, tap, press scale, and light elevation.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.color,
    this.bordered = true,
    this.elevated = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? color;
  final bool bordered;
  final bool elevated;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusLg);
    final canPress = widget.onTap != null;

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: AnimatedScale(
        scale: _pressed && canPress ? 0.97 : 1,
        duration: AppMotion.press,
        curve: _pressed
            ? AppMotion.emphasizedAccelerate
            : AppMotion.softSpring,
        child: AnimatedContainer(
          duration: AppMotion.press,
          curve: AppMotion.emphasized,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: widget.elevated && isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _pressed ? 0.04 : 0.07,
                      ),
                      blurRadius: _pressed ? 6 : 14,
                      offset: Offset(0, _pressed ? 2 : 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: widget.color ?? scheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: widget.bordered
                  ? BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.9),
                    )
                  : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              onTapDown:
                  canPress ? (_) => setState(() => _pressed = true) : null,
              onTapUp:
                  canPress ? (_) => setState(() => _pressed = false) : null,
              onTapCancel:
                  canPress ? () => setState(() => _pressed = false) : null,
              borderRadius: radius,
              child: Padding(padding: widget.padding, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty / error placeholder.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.illustration,
    this.primaryLabel,
    this.onPrimary,
    this.primaryIcon,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryIcon,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  });

  final String title;
  final String subtitle;
  final Widget? illustration;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final IconData? primaryIcon;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData? secondaryIcon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FadeRiseIn(
      child: Center(
        child: SingleChildScrollView(
          padding: padding,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              illustration ??
                  _DefaultDocIllustration(color: scheme.primary),
              const SizedBox(height: 20),
              Text(
                title,
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 20),
                AppButton.filled(
                  label: primaryLabel!,
                  onPressed: onPrimary,
                  icon: primaryIcon ?? Icons.document_scanner_outlined,
                  expand: true,
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 8),
                AppButton.outlined(
                  label: secondaryLabel!,
                  onPressed: onSecondary,
                  icon: secondaryIcon ?? Icons.picture_as_pdf_outlined,
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DefaultDocIllustration extends StatelessWidget {
  const _DefaultDocIllustration({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? scheme.surfaceContainerHigh : Colors.white;
    final line = scheme.outlineVariant;

    return SizedBox(
      width: 168,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft navy glow
          Positioned(
            bottom: 18,
            child: Container(
              width: 120,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Back page
          Positioned(
            left: 28,
            top: 22,
            child: Transform.rotate(
              angle: -0.14,
              child: _DocSheet(
                width: 78,
                height: 96,
                color: color.withValues(alpha: 0.12),
                border: color.withValues(alpha: 0.22),
              ),
            ),
          ),
          // Mid page
          Positioned(
            right: 30,
            top: 18,
            child: Transform.rotate(
              angle: 0.12,
              child: _DocSheet(
                width: 82,
                height: 100,
                color: paper,
                border: line,
                showLines: true,
                lineColor: line,
              ),
            ),
          ),
          // Front page (centered)
          Positioned(
            top: 12,
            child: _DocSheet(
              width: 88,
              height: 108,
              color: paper,
              border: scheme.outline.withValues(alpha: 0.55),
              elevated: true,
              showLines: true,
              lineColor: line,
              accentCorner: color,
            ),
          ),
          // Scanner frame corners
          Positioned(
            top: 6,
            child: SizedBox(
              width: 108,
              height: 118,
              child: CustomPaint(
                painter: _ScanFramePainter(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocSheet extends StatelessWidget {
  const _DocSheet({
    required this.width,
    required this.height,
    required this.color,
    required this.border,
    this.showLines = false,
    this.lineColor,
    this.elevated = false,
    this.accentCorner,
  });

  final double width;
  final double height;
  final Color color;
  final Color border;
  final bool showLines;
  final Color? lineColor;
  final bool elevated;
  final Color? accentCorner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: showLines
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (accentCorner != null)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: accentCorner!.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: accentCorner,
                    ),
                  )
                else
                  const SizedBox(height: 4),
                _line(lineColor!, 1),
                const SizedBox(height: 7),
                _line(lineColor!, 0.85),
                const SizedBox(height: 7),
                _line(lineColor!, 0.55),
              ],
            )
          : null,
    );
  }

  Widget _line(Color c, double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 16.0;
    // Top-left
    canvas.drawLine(const Offset(0, len), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(len, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - len, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    // Bottom-left
    canvas.drawLine(
      Offset(0, size.height - len),
      Offset(0, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Shared search field — Home + Files.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Search documents and tags',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.dense = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasText = controller.text.trim().isNotEmpty;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: dense ? text.bodyMedium : text.bodyLarge,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onTapOutside: (_) => focusNode?.unfocus(),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(Icons.search, size: dense ? 20 : 22),
            isDense: dense,
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: dense ? 10 : 14,
            ),
            suffixIcon: hasText
                ? IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close, size: dense ? 18 : 20),
                    onPressed: () {
                      controller.clear();
                      onClear?.call();
                      onChanged?.call('');
                      focusNode?.unfocus();
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Error placeholder — same CTA pattern as empty, clearer semantics.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.subtitle = 'Please try again.',
    this.retryLabel = 'Try again',
    this.onRetry,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
  });

  final String title;
  final String subtitle;
  final String retryLabel;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      subtitle: subtitle,
      primaryLabel: onRetry == null ? null : retryLabel,
      primaryIcon: Icons.refresh,
      onPrimary: onRetry,
      padding: padding,
      illustration: Icon(
        Icons.error_outline,
        size: 56,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}

/// Inline / full-screen short loading with contextual message.
class AppLoadingState extends StatelessWidget {
  const AppLoadingState({
    super.key,
    required this.message,
    this.subtitle,
  });

  final String message;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 18),
            Text(message, style: text.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress card for long saves / exports (title + detail + bar).
class AppProgressCard extends StatelessWidget {
  const AppProgressCard({
    super.key,
    required this.title,
    required this.detail,
    this.progress,
  });

  final String title;
  final String detail;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              value: progress,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(minHeight: 3, value: progress),
        ],
      ),
    );
  }
}

/// Skeleton placeholders for document lists (known structure).
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}

/// Dimmed overlay with spinner + friendly label.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.message,
    this.progress,
  });

  final String message;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: FadeRiseIn(
          offset: 10,
          duration: AppMotion.quick,
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
            bordered: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (progress != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                      ),
                    )
                  else
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'This stays on your device',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

/// Explicit AppBar back when [Navigator.canPop].
///
/// Prefer [scanMeAppBarLeading] so the AppBar omits leading on root routes
/// (avoids an empty 56px slot).
class AppBarBackButton extends StatelessWidget {
  const AppBarBackButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return BackButton(
      color: color,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}

/// Null when this route cannot pop — use as `AppBar(leading: …)`.
Widget? scanMeAppBarLeading(BuildContext context, {Color? color}) {
  if (!Navigator.of(context).canPop()) return null;
  return AppBarBackButton(color: color);
}

/// Circular icon button on a soft surface (settings, overflow, etc.).
/// Prefer [tooltip] for a11y — falls back to generic “Button”.
class AppCircleIconButton extends StatelessWidget {
  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppTheme.iconTap,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = tooltip ?? 'Button';
    final btn = Semantics(
      button: true,
      label: label,
      child: Material(
        color: scheme.surface,
        shape: CircleBorder(
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        ),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 24, color: scheme.onSurface),
          ),
        ),
      ),
    );
    return Tooltip(message: label, child: btn);
  }
}

/// Section label with optional trailing action (Library, Appearance…).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 8, 8),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: text.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Alias — design-system name for [AppCircleIconButton].
typedef AppIconButton = AppCircleIconButton;

/// Alias — design-system name for [SectionHeader].
typedef AppSectionHeader = SectionHeader;

/// Privacy / offline trust chip — “stays on this device”.
class PrivacyBadge extends StatelessWidget {
  const PrivacyBadge({
    super.key,
    this.label = 'Private · On this device',
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: compact ? 16 : 18,
              color: scheme.primary,
            ),
            SizedBox(width: compact ? 6 : 8),
            Flexible(
              child: Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Meta chip for document cards (pages, PDF, size, date).
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.label,
    this.color,
  });

  final String label;
  /// Optional brand/tag color (fill + contrasting label).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color?.withValues(alpha: 0.18) ??
        scheme.surfaceContainerHighest.withValues(alpha: 0.85);
    final fg = color ?? scheme.onSurfaceVariant;
    final border = color?.withValues(alpha: 0.45) ??
        scheme.outlineVariant.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext ctx) builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: true,
    transitionAnimationController: null,
    builder: (ctx) {
      final routeAnim = ModalRoute.of(ctx)?.animation;
      final content = SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: builder(ctx),
        ),
      );
      if (routeAnim == null) return content;
      final curved = CurvedAnimation(
        parent: routeAnim,
        curve: AppMotion.emphasizedDecelerate,
        reverseCurve: AppMotion.emphasizedAccelerate,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
            alignment: Alignment.bottomCenter,
            child: content,
          ),
        ),
      );
    },
  );
}

Future<bool> showConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
  IconData icon = Icons.warning_amber_rounded,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (destructive ? scheme.error : scheme.primary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: destructive ? scheme.error : scheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, AppTheme.tapMin),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: destructive
                        ? FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                            minimumSize: const Size(48, AppTheme.tapMin),
                          )
                        : FilledButton.styleFrom(
                            minimumSize: const Size(48, AppTheme.tapMin),
                          ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}
