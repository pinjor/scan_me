import 'package:flutter/material.dart';

/// Shared route: soft fade + slight rise (push / pop).
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.fullscreenDialog,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: AppMotion.pageForward,
          reverseTransitionDuration: AppMotion.pageBack,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final secondary = CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0.025),
                  end: Offset.zero,
                ).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(-0.02, 0),
                  ).animate(secondary),
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

abstract final class AppMotion {
  static const pageForward = Duration(milliseconds: 320);
  static const pageBack = Duration(milliseconds: 260);
  static const quick = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 420);
  static const chip = Duration(milliseconds: 220);
  static const listItem = Duration(milliseconds: 360);
}

/// Fade + rise once on first build (empty states, section headers).
class FadeRiseIn extends StatelessWidget {
  const FadeRiseIn({
    super.key,
    required this.child,
    this.duration = AppMotion.medium,
    this.delay = Duration.zero,
    this.offset = 16,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Staggered list-row entrance.
class StaggeredListItem extends StatefulWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.maxStagger = 10,
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
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    final i = widget.index.clamp(0, widget.maxStagger);
    Future<void>.delayed(Duration(milliseconds: 35 * i), () {
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
    return FadeTransition(
      opacity: _t,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(_t),
        child: widget.child,
      ),
    );
  }
}

/// Cross-fade / size for body swaps (loading → list → empty).
class AppBodySwitch extends StatelessWidget {
  const AppBodySwitch({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous,
            if (current != null) current,
          ],
        );
      },
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
