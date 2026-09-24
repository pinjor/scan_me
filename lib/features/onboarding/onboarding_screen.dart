import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';

enum _HeroKind { welcome, tags, ready }

class _Page {
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.chips,
    required this.hero,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> chips;
  final _HeroKind hero;
}

const _pages = <_Page>[
  _Page(
    eyebrow: 'ScanMe',
    title: 'Welcome to ScanMe',
    body: 'Fast document scans — all on this phone.',
    chips: ['100% offline'],
    hero: _HeroKind.welcome,
  ),
  _Page(
    eyebrow: 'Personalize',
    title: 'Make it yours',
    body: 'Tag scans your way. Pick a look that feels like home.',
    chips: [],
    hero: _HeroKind.tags,
  ),
  _Page(
    eyebrow: 'Ready',
    title: "You're good to go",
    body: 'Capture pages, save PDFs, keep them here — 100% offline.',
    chips: [],
    hero: _HeroKind.ready,
  ),
];

bool _isWidgetTestBinding() {
  final name = WidgetsBinding.instance.runtimeType.toString();
  return name.contains('Test');
}

/// First-run light look — brand navy/teal on warm paper (not app dark mode).
ThemeData _onboardingTheme(BuildContext context) {
  final base = Theme.of(context);
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppTheme.navy,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFD5E4EC),
    onPrimaryContainer: AppTheme.ink,
    secondary: AppTheme.accent,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD2E8EB),
    onSecondaryContainer: Color(0xFF0E3D44),
    tertiary: Color(0xFF5A7A6A),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFDCE8E0),
    onTertiaryContainer: Color(0xFF1E3328),
    error: Color(0xFFB3261E),
    onError: Colors.white,
    surface: AppTheme.paper,
    onSurface: AppTheme.ink,
    onSurfaceVariant: Color(0xFF5A6670),
    outline: Color(0xFFB8C0C6),
    outlineVariant: Color(0xFFD9D2C8),
    shadow: AppTheme.ink,
    scrim: AppTheme.ink,
    inverseSurface: AppTheme.ink,
    onInverseSurface: AppTheme.paper,
    inversePrimary: AppTheme.navyOnDark,
    surfaceTint: AppTheme.navy,
  );
  return base.copyWith(
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppTheme.paper,
    textTheme: base.textTheme.apply(
      bodyColor: AppTheme.ink,
      displayColor: AppTheme.ink,
    ),
  );
}

/// First-run tour. [replay] pops on finish instead of swapping the app root.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController(viewportFraction: 0.92);
  var _index = 0;
  late final AnimationController _float;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppMotion.reduce(context) || _isWidgetTestBinding()) return;
      _float.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _float.dispose();
    _enter.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    if (widget.replay) Navigator.pop(context);
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    _enter
      ..reset()
      ..forward();
    _controller.animateToPage(
      i,
      duration: AppMotion.pageForward,
      curve: AppMotion.emphasizedDecelerate,
    );
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
    _enter
      ..reset()
      ..forward();
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      HapticFeedback.mediumImpact();
      _finish();
      return;
    }
    _go(_index + 1);
  }

  void _back() {
    if (_index <= 0) return;
    _go(_index - 1);
  }

  @override
  Widget build(BuildContext context) {
    final onboardingTheme = _onboardingTheme(context);
    return Theme(
      data: onboardingTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppTheme.paper,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: _OnboardingBody(
          replay: widget.replay,
          index: _index,
          last: _index == _pages.length - 1,
          float: _float,
          enter: _enter,
          controller: _controller,
          onBack: _back,
          onGo: _go,
          onPageChanged: _onPageChanged,
          onNext: _next,
          onFinish: _finish,
        ),
      ),
    );
  }
}

class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody({
    required this.replay,
    required this.index,
    required this.last,
    required this.float,
    required this.enter,
    required this.controller,
    required this.onBack,
    required this.onGo,
    required this.onPageChanged,
    required this.onNext,
    required this.onFinish,
  });

  final bool replay;
  final int index;
  final bool last;
  final AnimationController float;
  final AnimationController enter;
  final PageController controller;
  final VoidCallback onBack;
  final ValueChanged<int> onGo;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = AppMotion.reduce(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([float, controller]),
              builder: (context, _) {
                final page = controller.hasClients
                    ? (controller.page ?? index.toDouble())
                    : index.toDouble();
                return _AmbientWash(
                  page: page,
                  breathe: reduce ? 0 : float.value,
                );
              },
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: AnimatedOpacity(
                          opacity: index > 0 ? 1 : 0,
                          duration: AppMotion.quick,
                          child: IgnorePointer(
                            ignoring: index == 0,
                            child: IconButton(
                              tooltip: 'Back',
                              onPressed: onBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _pages.length; i++)
                              GestureDetector(
                                onTap: () => onGo(i),
                                child: AnimatedContainer(
                                  duration: AppMotion.medium,
                                  // easeOut — softSpring overshoots and can
                                  // lerp BoxShadow blur negative (test crash).
                                  curve: Curves.easeOutCubic,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  height: 8,
                                  width: i == index ? 28 : 8,
                                  decoration: BoxDecoration(
                                    color: i == index
                                        ? AppTheme.navy
                                        : AppTheme.navy.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(99),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.navy.withValues(
                                          alpha: i == index ? 0.2 : 0,
                                        ),
                                        blurRadius: i == index ? 8 : 0,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onFinish,
                            child: Text(replay ? 'Close' : 'Skip'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 4),
                  child: _ProgressBar(
                    value: (index + 1) / _pages.length,
                    color: AppTheme.accent,
                    track: AppTheme.navy.withValues(alpha: 0.1),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: controller,
                    itemCount: _pages.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      return AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          var scale = 1.0;
                          var opacity = 1.0;
                          if (controller.hasClients &&
                              controller.position.haveDimensions) {
                            final page = controller.page ?? index.toDouble();
                            final delta = (page - i).abs().clamp(0.0, 1.0);
                            scale = 1 - (delta * 0.06);
                            opacity = 1 - (delta * 0.35);
                          }
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: float,
                                    builder: (context, child) {
                                      final t = reduce ? 0.0 : float.value;
                                      final bob = math.sin(t * math.pi) * 6;
                                      return Transform.translate(
                                        offset: Offset(0, bob),
                                        child: child,
                                      );
                                    },
                                    child: FadeRiseIn(
                                      key: ValueKey('hero-$i-$index'),
                                      duration: AppMotion.slow,
                                      offset: 22,
                                      scaleFrom: 0.88,
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: _OnboardingHero(
                                          kind: p.hero,
                                          float: reduce ? 0 : float.value,
                                          active: i == index,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Flexible(
                                flex: 4,
                                child: SingleChildScrollView(
                                  child: AnimatedBuilder(
                                    animation: enter,
                                    builder: (context, _) {
                                      final e = CurvedAnimation(
                                        parent: enter,
                                        curve: AppMotion.emphasizedDecelerate,
                                      ).value;
                                      Widget stagger(
                                        int step,
                                        Widget child,
                                      ) {
                                        final start = (step * 0.12).clamp(
                                          0.0,
                                          0.7,
                                        );
                                        final local =
                                            ((e - start) / (1 - start)).clamp(
                                              0.0,
                                              1.0,
                                            );
                                        return Opacity(
                                          opacity: local,
                                          child: Transform.translate(
                                            offset: Offset(
                                              0,
                                              18 * (1 - local),
                                            ),
                                            child: Transform.scale(
                                              scale: 0.96 + (0.04 * local),
                                              child: child,
                                            ),
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: [
                                          stagger(
                                            0,
                                            Text(
                                              p.eyebrow.toUpperCase(),
                                              style: text.labelSmall?.copyWith(
                                                color: AppTheme.accent,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          stagger(
                                            1,
                                            Text(
                                              p.title,
                                              textAlign: TextAlign.center,
                                              style: text.headlineMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.12,
                                                    color: scheme.onSurface,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          stagger(
                                            2,
                                            Text(
                                              p.body,
                                              textAlign: TextAlign.center,
                                              style: text.bodyLarge?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                          if (p.chips.isNotEmpty) ...[
                                            const SizedBox(height: 20),
                                            stagger(
                                              3,
                                              Wrap(
                                                alignment:
                                                    WrapAlignment.center,
                                                spacing: 10,
                                                runSpacing: 10,
                                                children: [
                                                  for (var c = 0;
                                                      c < p.chips.length;
                                                      c++)
                                                    _SoftChip(
                                                      label: p.chips[c],
                                                      delayMs: 80 + (c * 70),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('cta-$index'),
                    tween: Tween(begin: 0.92, end: 1),
                    duration: AppMotion.medium,
                    curve: AppMotion.softSpring,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: AppButton.filled(
                      label: last ? 'Get started' : 'Next',
                      icon: last
                          ? Icons.document_scanner_rounded
                          : Icons.arrow_forward_rounded,
                      expand: true,
                      onPressed: onNext,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.color,
    required this.track,
  });

  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.medium,
        curve: AppMotion.emphasizedDecelerate,
        builder: (context, v, _) {
          return LinearProgressIndicator(
            value: v,
            minHeight: 5,
            backgroundColor: track,
            color: color,
          );
        },
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, this.delayMs = 0});

  final String label;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return FadeRiseIn(
      delay: Duration(milliseconds: delayMs),
      offset: 10,
      scaleFrom: 0.85,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFD2E8EB),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: const Color(0xFF0E3D44),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AmbientWash extends StatelessWidget {
  const _AmbientWash({required this.page, required this.breathe});

  final double page;
  final double breathe;

  @override
  Widget build(BuildContext context) {
    final t = page / math.max(1, _pages.length - 1);
    final bob = breathe * 0.04;
    // Brand paper + soft navy/teal washes only.
    final top = Color.lerp(
      const Color(0xFFE8EEF1), // soft navy mist
      const Color(0xFFE2EFF0), // soft teal mist
      t,
    )!;
    final bottom = Color.lerp(
      const Color(0xFFEAF3F2),
      const Color(0xFFF0EBE4),
      t,
    )!;

    return Stack(
      children: [
        AnimatedContainer(
          duration: AppMotion.slow,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.7 + t * 0.3, -1),
              end: Alignment(0.8 - t * 0.2, 1.05),
              colors: [top, AppTheme.paper, bottom],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 36 + bob * 70,
          right: -48 + t * 24,
          child: _GlowOrb(
            size: 210,
            color: AppTheme.navy.withValues(alpha: 0.07),
          ),
        ),
        Positioned(
          bottom: 100 - bob * 50,
          left: -56 - t * 16,
          child: _GlowOrb(
            size: 190,
            color: AppTheme.accent.withValues(alpha: 0.09),
          ),
        ),
        Positioned(
          top: 210 - bob * 30,
          left: 48 + t * 36,
          child: _GlowOrb(
            size: 100,
            color: AppTheme.navy.withValues(alpha: 0.05),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({
    required this.kind,
    required this.float,
    required this.active,
  });

  final _HeroKind kind;
  final double float;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final child = switch (kind) {
      _HeroKind.welcome => _HeroWelcome(float: float),
      _HeroKind.tags => _HeroTags(float: float, active: active),
      _HeroKind.ready => _HeroReady(float: float, active: active),
    };
    return ExcludeSemantics(
      child: SizedBox(width: 340, height: 248, child: child),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 248,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: AppTheme.navy.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroWelcome extends StatelessWidget {
  const _HeroWelcome({required this.float});

  final double float;

  @override
  Widget build(BuildContext context) {
    final sway = (float - 0.5) * 0.08;
    return _Stage(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(30 + sway * 10, 12),
            child: Transform.rotate(
              angle: 0.14 + sway,
              child: const _SheetFace(color: Color(0xFFD2E8EB)),
            ),
          ),
          Transform.translate(
            offset: Offset(-20 - sway * 8, 2),
            child: Transform.rotate(
              angle: -0.1 - sway * 0.5,
              child: const _SheetFace(
                color: Colors.white,
                lined: true,
                brackets: true,
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            child: Transform.scale(
              scale: 1 + (math.sin(float * math.pi) * 0.04),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.navy,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.navy.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.document_scanner_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '100% offline',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetFace extends StatelessWidget {
  const _SheetFace({
    required this.color,
    this.lined = false,
    this.brackets = false,
  });

  final Color color;
  final bool lined;
  final bool brackets;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 176,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navy.withValues(alpha: 0.1)),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: CustomPaint(
        painter: lined || brackets
            ? _SheetPainter(
                line: AppTheme.ink.withValues(alpha: 0.1),
                corner: AppTheme.accent,
                lined: lined,
                brackets: brackets,
              )
            : null,
      ),
    );
  }
}

class _SheetPainter extends CustomPainter {
  _SheetPainter({
    required this.line,
    required this.corner,
    required this.lined,
    required this.brackets,
  });

  final Color line;
  final Color corner;
  final bool lined;
  final bool brackets;

  @override
  void paint(Canvas canvas, Size size) {
    if (lined) {
      final p = Paint()
        ..color = line
        ..strokeWidth = 1.4;
      for (var y = 28.0; y < size.height - 20; y += 14) {
        canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), p);
      }
    }
    if (brackets) {
      final p = Paint()
        ..color = corner
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      const s = 14.0;
      const inset = 10.0;
      void cornerAt(double x, double y, double dx, double dy) {
        canvas.drawLine(Offset(x, y + dy * s), Offset(x, y), p);
        canvas.drawLine(Offset(x, y), Offset(x + dx * s, y), p);
      }

      cornerAt(inset, inset, 1, 1);
      cornerAt(size.width - inset, inset, -1, 1);
      cornerAt(inset, size.height - inset, 1, -1);
      cornerAt(size.width - inset, size.height - inset, -1, -1);
    }
  }

  @override
  bool shouldRepaint(covariant _SheetPainter old) =>
      old.line != line || old.corner != corner;
}

class _HeroTags extends StatelessWidget {
  const _HeroTags({required this.float, required this.active});

  final double float;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final pills = const [
      (label: 'Work', color: AppTheme.navy),
      (label: 'Receipt', color: AppTheme.accent),
      (label: 'ID', color: Color(0xFF3D6B4F)),
    ];
    final swatches = const [
      AppTheme.navy,
      AppTheme.accent,
      Color(0xFF2D6A4F),
      Color(0xFF0F6C7A),
      Color(0xFF3D5A80),
    ];

    return _Stage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tags',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < pills.length; i++)
                Transform.translate(
                  offset: Offset(
                    0,
                    active ? math.sin((float + i * 0.3) * math.pi) * 3 : 0,
                  ),
                  child: FadeRiseIn(
                    delay: Duration(milliseconds: 80 * i),
                    offset: 12,
                    scaleFrom: 0.8,
                    child: _TagPill(
                      label: pills[i].label,
                      color: pills[i].color,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            'Themes',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Light, dark, or your colors',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < swatches.length; i++)
                Transform.scale(
                  scale: 1 + (active && i == 0 ? float * 0.08 : 0),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: swatches[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: i == 0 ? AppTheme.navy : Colors.white,
                        width: i == 0 ? 3 : 2,
                      ),
                      boxShadow: AppTheme.cardShadow(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroReady extends StatelessWidget {
  const _HeroReady({required this.float, required this.active});

  final double float;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final pulse = active ? 1 + (math.sin(float * math.pi) * 0.06) : 1.0;
    final ring = active ? 1 + (float * 0.35) : 1.0;

    return _Stage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: ring,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accent.withValues(
                          alpha: active ? (0.4 * (1 - float)) : 0.2,
                        ),
                        width: 3,
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppTheme.navy,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navy.withValues(alpha: 0.28),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.document_scanner_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '100% offline',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Brief gate while onboarding prefs load.
class OnboardingSplash extends StatelessWidget {
  const OnboardingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(child: CircularProgressIndicator(color: scheme.primary)),
    );
  }
}
