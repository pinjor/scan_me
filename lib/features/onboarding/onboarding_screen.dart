import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding.dart';
import '../../core/product_surface.dart';
import '../../core/services/access_permission.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';

enum _HeroKind { welcome, scan, review, library, tools, theme, access, ready }

class _Page {
  const _Page({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.chips,
    required this.hero,
    this.hideWhenScanOnly = false,
    this.scanBody,
    this.scanChips,
    this.accessAsk = false,
  });

  final String eyebrow;
  final String title;
  final String body;
  final List<String> chips;
  final _HeroKind hero;
  final bool hideWhenScanOnly;
  final String? scanBody;
  final List<String>? scanChips;
  final bool accessAsk;

  String get copy => kScanOnlySurface && scanBody != null ? scanBody! : body;

  List<String> get labels =>
      kScanOnlySurface && scanChips != null ? scanChips! : chips;
}

const _pages = <_Page>[
  _Page(
    eyebrow: 'Private by default',
    title: 'Welcome to ScanMe',
    body:
        'Offline document scanner by Apptriangle. Files stay on this phone — no account, no cloud.',
    chips: ['Scan to PDF', 'Works offline'],
    hero: _HeroKind.welcome,
  ),
  _Page(
    eyebrow: 'Capture',
    title: 'Scan from the middle button',
    body:
        'The raised Scan button opens the system camera. Capture a page, add more, then continue.',
    chips: ['CamScan B&W', 'Multi-page drafts'],
    hero: _HeroKind.scan,
  ),
  _Page(
    eyebrow: 'Edit & export',
    title: 'Review, then save',
    body:
        'Enhance, rotate, or retake pages. Save as PDF, images, or both. Pick a folder with Save as…',
    chips: ['B&W · vivid', 'Save as…'],
    hero: _HeroKind.review,
  ),
  _Page(
    eyebrow: 'Library',
    title: 'Home is your library',
    body:
        'Search, shortcut tiles, and every file in one list. Filter All, Favorites, Tags, or Deleted.',
    chips: ['Favorites', 'Tags'],
    hero: _HeroKind.library,
  ),
  _Page(
    eyebrow: 'Toolkit',
    title: 'Convert, photos, PDF tools',
    body:
        'Convert tab handles PDF, Word, Excel, and more. Edit photo crops, resizes, and compresses. PDF Tools merge, split, and shrink files.',
    chips: ['QR reader', 'Open with'],
    hero: _HeroKind.tools,
    hideWhenScanOnly: true,
  ),
  _Page(
    eyebrow: 'Personalize',
    title: 'Make it yours',
    body:
        'Me holds themes (single, dual, triple, or your own), light/dark, and the two nav slots beside Scan.',
    chips: ['40+ themes', 'Nav slots'],
    hero: _HeroKind.theme,
    scanBody:
        'Me holds themes (single, dual, triple, or your own) and light/dark.',
    scanChips: ['40+ themes', 'Light / dark'],
  ),
  _Page(
    eyebrow: 'Access',
    title: 'We ask before we look',
    body:
        'When you tap a feature, ScanMe explains why, then the system asks. Camera for scan and QR. Photos you choose. Files through the system picker — not your whole phone.',
    chips: ['Camera', 'Photos', 'Files'],
    hero: _HeroKind.access,
    accessAsk: true,
    scanBody:
        'When you tap a feature, ScanMe explains why, then the system asks. Camera for scan. Photos you choose. Files through the system picker — not your whole phone.',
  ),
  _Page(
    eyebrow: 'All set',
    title: "You're ready",
    body:
        'Tap Scan for the first page. Convert or Edit photo when you already have a file.',
    chips: ['On this device', 'Replay in Me'],
    hero: _HeroKind.ready,
    scanBody:
        'Tap Scan for the first page. Import photos into a scan from Home shortcuts.',
  ),
];

List<_Page> get _visiblePages => kScanOnlySurface
    ? _pages.where((p) => !p.hideWhenScanOnly).toList()
    : _pages;

/// First-run feature tour. [replay] pops on finish instead of swapping the app root.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.replay = false});

  final bool replay;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  @override
  void dispose() {
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
    _controller.animateToPage(
      i,
      duration: AppMotion.pageForward,
      curve: AppMotion.emphasizedDecelerate,
    );
  }

  void _next() {
    if (_index >= _visiblePages.length - 1) {
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final last = _index == _visiblePages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientWash()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: _index > 0
                            ? IconButton(
                                tooltip: 'Back',
                                onPressed: _back,
                                icon: const Icon(Icons.arrow_back_rounded),
                              )
                            : const SizedBox.shrink(),
                      ),
                      Expanded(
                        child: Text(
                          '${_index + 1} of ${_visiblePages.length}',
                          textAlign: TextAlign.center,
                          style: text.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 88,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _finish,
                            child: Text(widget.replay ? 'Close' : 'Skip'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                  child: _ProgressBar(
                    value: (_index + 1) / _visiblePages.length,
                    color: scheme.primary,
                    track: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _visiblePages.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _index = i);
                    },
                    itemBuilder: (context, i) {
                      final p = _visiblePages[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 5,
                              child: FadeRiseIn(
                                key: ValueKey('hero-$i'),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: _OnboardingHero(kind: p.hero),
                                  ),
                                ),
                              ),
                            ),
                            Flexible(
                              flex: 4,
                              child: SingleChildScrollView(
                                child: FadeRiseIn(
                                  key: ValueKey('copy-$i'),
                                  delay: const Duration(milliseconds: 40),
                                  child: Column(
                                    children: [
                                      Text(
                                        p.eyebrow.toUpperCase(),
                                        style: text.labelSmall?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        p.title,
                                        textAlign: TextAlign.center,
                                        style: text.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        p.copy,
                                        textAlign: TextAlign.center,
                                        style: text.bodyLarge?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          if (i == 0)
                                            const PrivacyBadge(
                                              label: 'No account · on device',
                                              compact: true,
                                            ),
                                          for (final chip in p.labels)
                                            _SoftChip(label: chip),
                                        ],
                                      ),
                                      if (p.accessAsk) ...[
                                        const SizedBox(height: 16),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              AccessPermission.ensureCamera(
                                                context,
                                              ),
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                          ),
                                          label: const Text('Allow camera'),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              AccessPermission.ensurePhotos(
                                                context,
                                              ),
                                          icon: const Icon(
                                            Icons.photo_library_outlined,
                                          ),
                                          label: const Text('Allow photos'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: AppButton.filled(
                    label: last ? 'Get started' : 'Next',
                    icon: last
                        ? Icons.document_scanner_rounded
                        : Icons.arrow_forward_rounded,
                    expand: true,
                    onPressed: _next,
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

class _AmbientWash extends StatelessWidget {
  const _AmbientWash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerLow, scheme.surface],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _Blob(
              size: 260,
              color: scheme.primary.withValues(alpha: light ? 0.10 : 0.18),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: _Blob(
              size: 220,
              color: scheme.tertiary.withValues(alpha: light ? 0.08 : 0.14),
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
    return LayoutBuilder(
      builder: (context, c) {
        return SizedBox(
          height: 4,
          child: Stack(
            children: [
              Container(
                width: c.maxWidth,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              AnimatedContainer(
                duration: AppMotion.medium,
                curve: AppMotion.emphasized,
                width: (c.maxWidth * value).clamp(4, c.maxWidth),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.8)),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? AppTheme.cardShadow(pressed: true)
            : null,
      ),
      child: Text(
        label,
        style: text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _OnboardingHero extends StatelessWidget {
  const _OnboardingHero({required this.kind});

  final _HeroKind kind;

  @override
  Widget build(BuildContext context) {
    final child = switch (kind) {
      _HeroKind.welcome => const _HeroWelcome(),
      _HeroKind.scan => const _HeroScan(),
      _HeroKind.review => const _HeroReview(),
      _HeroKind.library => const _HeroLibrary(),
      _HeroKind.tools => const _HeroTools(),
      _HeroKind.theme => const _HeroTheme(),
      _HeroKind.access => const _HeroAccess(),
      _HeroKind.ready => const _HeroReady(),
    };
    return ExcludeSemantics(
      child: SizedBox(width: 340, height: 236, child: child),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = Theme.of(context).brightness == Brightness.light;
    return Container(
      width: 340,
      height: 236,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: light ? 0.7 : 0.9),
        ),
        boxShadow: light ? AppTheme.floatShadow() : null,
      ),
      child: child,
    );
  }
}

class _HeroWelcome extends StatelessWidget {
  const _HeroWelcome();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Stage(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(28, 10),
            child: Transform.rotate(
              angle: 0.12,
              child: _SheetFace(
                color: scheme.primaryContainer.withValues(alpha: 0.65),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(-18, 4),
            child: Transform.rotate(
              angle: -0.08,
              child: _SheetFace(
                color: scheme.surface,
                lined: true,
                brackets: true,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(99),
                boxShadow: AppTheme.floatShadow(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 16, color: scheme.onPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Stays on this phone',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 132,
      height: 176,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: CustomPaint(
        painter: lined || brackets
            ? _SheetPainter(
                line: scheme.onSurface.withValues(alpha: 0.12),
                corner: scheme.primary,
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

class _HeroScan extends StatelessWidget {
  const _HeroScan();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Stage(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        children: [
          const Spacer(),
          SizedBox(
            height: 88,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 64,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                      child: Row(
                        children: [
                          _NavGlyph(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            dim: true,
                          ),
                          _NavGlyph(
                            icon: Icons.photo_outlined,
                            label: 'Photo',
                            dim: true,
                          ),
                          const Spacer(),
                          _NavGlyph(
                            icon: Icons.swap_horiz,
                            label: 'Convert',
                            dim: true,
                          ),
                          _NavGlyph(
                            icon: Icons.person_outline,
                            label: 'Me',
                            dim: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.18),
                            width: 2,
                          ),
                        ),
                      ),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.document_scanner_rounded,
                          color: scheme.onPrimary,
                          size: 28,
                        ),
                      ),
                    ],
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

class _NavGlyph extends StatelessWidget {
  const _NavGlyph({required this.icon, required this.label, this.dim = false});

  final IconData icon;
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = dim ? scheme.onSurfaceVariant : scheme.primary;
    return SizedBox(
      width: 52,
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroReview extends StatelessWidget {
  const _HeroReview();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Stage(
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
              ),
              child: CustomPaint(
                painter: _SheetPainter(
                  line: scheme.onSurface.withValues(alpha: 0.14),
                  corner: scheme.primary,
                  lined: true,
                  brackets: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Enhance',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const _FilterPill(label: 'Original'),
                const SizedBox(height: 8),
                const _FilterPill(label: 'B&W', selected: true),
                const SizedBox(height: 8),
                const _FilterPill(label: 'Vivid'),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Save PDF',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w700,
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

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HeroLibrary extends StatelessWidget {
  const _HeroLibrary();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return _Stage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Search files',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _Shortcut(icon: Icons.download_outlined, label: 'Import'),
              SizedBox(width: 8),
              _Shortcut(icon: Icons.qr_code_2, label: 'QR'),
              SizedBox(width: 8),
              _Shortcut(icon: Icons.photo_outlined, label: 'Photo'),
              SizedBox(width: 8),
              _Shortcut(icon: Icons.picture_as_pdf_outlined, label: 'PDF'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 54,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 20,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Lease · page 1',
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'PDF · today',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.bookmark_rounded, color: scheme.primary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: scheme.primary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTools extends StatelessWidget {
  const _HeroTools();

  @override
  Widget build(BuildContext context) {
    return const _Stage(
      child: Column(
        children: [
          Row(
            children: [
              _ToolTile(icon: Icons.swap_horiz, label: 'Convert'),
              SizedBox(width: 10),
              _ToolTile(icon: Icons.crop_outlined, label: 'Edit photo'),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              _ToolTile(icon: Icons.call_merge, label: 'Merge PDF'),
              SizedBox(width: 10),
              _ToolTile(icon: Icons.qr_code_scanner, label: 'QR reader'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        height: 90,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const Spacer(),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroTheme extends StatelessWidget {
  const _HeroTheme();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const swatches = [
      Color(0xFF1B3A4B),
      Color(0xFF2A7A86),
      Color(0xFF3D6B4F),
      Color(0xFF8B4A3A),
      Color(0xFF5B4B8A),
    ];
    return _Stage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Themes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Single · dual · triple · yours',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < swatches.length; i++)
                Container(
                  width: i == 0 ? 44 : 38,
                  height: i == 0 ? 44 : 38,
                  decoration: BoxDecoration(
                    color: swatches[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == 0 ? scheme.primary : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: i == 0 ? AppTheme.cardShadow() : null,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _ModeChip(label: 'Light', selected: true)),
              const SizedBox(width: 8),
              const Expanded(child: _ModeChip(label: 'Dark')),
              const SizedBox(width: 8),
              const Expanded(child: _ModeChip(label: 'System')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: selected ? scheme.primary : scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeroAccess extends StatelessWidget {
  const _HeroAccess();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget bubble(IconData icon, String label) {
      return Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(icon),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      );
    }

    return _Stage(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          bubble(Icons.photo_camera_outlined, 'Camera'),
          bubble(Icons.photo_library_outlined, 'Photos'),
          bubble(Icons.folder_open_outlined, 'Files'),
        ],
      ),
    );
  }
}

class _HeroReady extends StatelessWidget {
  const _HeroReady();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Stage(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.check_rounded, size: 44, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'ScanMe is ready',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap Scan when you are',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Brief branded hold while onboarding prefs load.
class OnboardingSplash extends StatelessWidget {
  const OnboardingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientWash()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.floatShadow(),
                  ),
                  child: Icon(
                    Icons.document_scanner_rounded,
                    size: 34,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'ScanMe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Private document scanner',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
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
