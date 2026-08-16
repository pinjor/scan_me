import 'package:flutter/material.dart';

/// Shared motion tokens — modern, calm, Material 3–leaning.
///
/// Prefer these over raw [Duration]/[Curves] so the app feels consistent.
abstract final class AppMotion {
  /// Incoming screens / sheets settle.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Content fades/slides in.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Content leaves / press release.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// Soft spring-ish for press / FAB.
  static const Curve softSpring = Cubic(0.34, 1.4, 0.64, 1.0);

  static const pageForward = Duration(milliseconds: 360);
  static const pageBack = Duration(milliseconds: 300);
  static const quick = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 380);
  static const chip = Duration(milliseconds: 200);
  static const listItem = Duration(milliseconds: 320);
  static const press = Duration(milliseconds: 100);
  static const sheet = Duration(milliseconds: 320);
  static const tab = Duration(milliseconds: 320);

  static bool reduce(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration maybeZero(BuildContext context, Duration d) =>
      reduce(context) ? Duration.zero : d;
}

/// Shared route: clear horizontal slide + fade (readable on device).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          opaque: true,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppMotion.pageForward,
          reverseTransitionDuration: AppMotion.pageBack,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (AppMotion.reduce(context)) return child;

            final incoming = CurvedAnimation(
              parent: animation,
              curve: AppMotion.emphasizedDecelerate,
              reverseCurve: AppMotion.emphasizedAccelerate,
            );
            final outgoing = CurvedAnimation(
              parent: secondaryAnimation,
              curve: AppMotion.emphasized,
            );

            // Incoming page: from right + fade in.
            final slideIn = Tween<Offset>(
              begin: const Offset(0.22, 0),
              end: Offset.zero,
            ).animate(incoming);
            final fadeIn = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
              ),
            );

            // Underlying page: eases slightly left (shared axis).
            final slideOut = Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.12, 0),
            ).animate(outgoing);

            return SlideTransition(
              position: slideOut,
              child: SlideTransition(
                position: slideIn,
                child: FadeTransition(
                  opacity: fadeIn,
                  child: child,
                ),
              ),
            );
          },
        );

  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Widget page, {
    String? name,
  }) {
    return Navigator.of(context).push<T>(
      AppPageRoute<T>(
        builder: (_) => page,
        settings: name != null ? RouteSettings(name: name) : null,
      ),
    );
  }
}

/// Fade + rise (+ soft scale) once on first build.
class FadeRiseIn extends StatelessWidget {
  const FadeRiseIn({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.delay = Duration.zero,
    this.offset = 12,
    this.scaleFrom = 0.98,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return child;
    final total = duration + delay;
    final start = total.inMilliseconds == 0
        ? 0.0
        : delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        start.clamp(0.0, 1.0),
        1,
        curve: AppMotion.emphasizedDecelerate,
      ),
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - v)),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * v,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Staggered list-row entrance — short, subtle, not flashy.
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxStagger = 8,
  });

  final int index;
  final Widget child;
  final int maxStagger;

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.listItem);
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: AppMotion.emphasizedDecelerate,
    );
    final i = widget.index.clamp(0, widget.maxStagger);
    Future<void>.delayed(Duration(milliseconds: 28 * i), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduce(context)) return widget.child;
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(_t),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(_t),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Cross-fade / soft rise for body swaps (loading → list → empty).
class AppBodySwitch extends StatelessWidget {
  const AppBodySwitch({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.maybeZero(context, AppMotion.medium);
    return AnimatedSwitcher(
      duration: d,
      switchInCurve: AppMotion.emphasizedDecelerate,
      switchOutCurve: AppMotion.emphasizedAccelerate,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            ?current,
          ],
        );
      },
      transitionBuilder: (child, anim) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: AppMotion.emphasizedDecelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.015),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.99, end: 1).animate(curved),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Soft press scale for tappable chrome (tool tiles, nav icons).
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.94,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.scale : 1,
      duration: AppMotion.press,
      curve: _pressed ? AppMotion.emphasizedAccelerate : AppMotion.softSpring,
      child: widget.child,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => _pressed = false),
      child: widget.borderRadius == null
          ? child
          : ClipRRect(borderRadius: widget.borderRadius!, child: child),
    );
  }
}
