import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/store_update_reminder.dart';
import '../../shared/widgets/app_transitions.dart';
import '../converters/converters_hub_screen.dart';
import '../converters/image_formats_hub_screen.dart';
import '../pdf_tools/pdf_tools_hub_screen.dart';
import '../settings/settings_screen.dart';
import 'home_dashboard_screen.dart';
import 'home_flows.dart';
import 'nav_catalog.dart';

/// Bottom nav: Home · [slot] · [Scan FAB] · [slot] · Me.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

enum _ShellTab { home, innerLeft, innerRight, me }

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  var _tab = _ShellTab.home;

  NavDest _destFor(_ShellTab tab, NavSlots slots) => switch (tab) {
    _ShellTab.home => NavDest.editPhoto, // unused
    _ShellTab.innerLeft => slots.innerLeft,
    _ShellTab.innerRight => slots.innerRight,
    _ShellTab.me => NavDest.convert, // unused
  };

  int _stackIndex(NavSlots slots) {
    if (_tab == _ShellTab.home) return 0;
    if (_tab == _ShellTab.me) return 2;
    final dest = _destFor(_tab, slots);
    return switch (dest) {
      NavDest.favorites => 0,
      NavDest.convert => 1,
      NavDest.editPhoto => 3,
      NavDest.pdfTools => 4,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      StoreUpdateReminder.maybeShow(context);
    });
  }

  void _go(_ShellTab tab, NavSlots slots) {
    FocusManager.instance.primaryFocus?.unfocus();
    final q = ref.read(libraryQueryProvider.notifier);
    if (tab == _ShellTab.home) q.showAll();
    if (tab == _ShellTab.innerLeft && slots.innerLeft == NavDest.favorites) {
      q.showFavorites();
    }
    if (tab == _ShellTab.innerRight && slots.innerRight == NavDest.favorites) {
      q.showFavorites();
    }
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  void _openConvert(NavSlots slots) {
    if (slots.innerLeft == NavDest.convert) {
      _go(_ShellTab.innerLeft, slots);
      return;
    }
    if (slots.innerRight == NavDest.convert) {
      _go(_ShellTab.innerRight, slots);
      return;
    }
    AppPageRoute.push(context, const ConvertersHubScreen());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slots = ref.watch(navSlotsProvider);
    final dest = _tab == _ShellTab.home || _tab == _ShellTab.me
        ? null
        : _destFor(_tab, slots);
    final homeActive = _tab == _ShellTab.home || dest == NavDest.favorites;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: PopScope(
        canPop: _tab == _ShellTab.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _tab != _ShellTab.home) _go(_ShellTab.home, slots);
        },
        child: IndexedStack(
          index: _stackIndex(slots),
          children: [
            HomeDashboardScreen(
              isActive: homeActive,
              onOpenTools: () => _openConvert(slots),
            ),
            const ConvertersHubScreen(embedded: true),
            const SettingsScreen(embedded: true),
            const ImageFormatsHubScreen(embedded: true),
            const PdfToolsHubScreen(embedded: true),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _ScanFab(
        color: scheme.primary,
        foreground: scheme.onPrimary,
        onPressed: () => HomeFlows.startScan(context),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: isDark ? 0 : 10,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        color: scheme.surface.withValues(alpha: isDark ? 0.92 : 0.96),
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
        height: 64,
        clipBehavior: Clip.antiAlias,
        notchMargin: 6,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                selected: _tab == _ShellTab.home,
                onTap: () => _go(_ShellTab.home, slots),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: slots.innerLeft.icon,
                selectedIcon: slots.innerLeft.selectedIcon,
                label: slots.innerLeft.navLabel,
                selected: _tab == _ShellTab.innerLeft,
                onTap: () => _go(_ShellTab.innerLeft, slots),
              ),
            ),
            const SizedBox(width: 72),
            Expanded(
              child: _NavItem(
                icon: slots.innerRight.icon,
                selectedIcon: slots.innerRight.selectedIcon,
                label: slots.innerRight.navLabel,
                selected: _tab == _ShellTab.innerRight,
                onTap: () => _go(_ShellTab.innerRight, slots),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.manage_accounts_outlined,
                selectedIcon: Icons.manage_accounts,
                label: 'Me',
                selected: _tab == _ShellTab.me,
                onTap: () => _go(_ShellTab.me, slots),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan Document',
      child: Tooltip(
        message: 'Scan Document',
        child: PressableScale(
          onTap: onPressed,
          scale: 0.94,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
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
              size: 28,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        onTap: onTap,
        scale: 0.92,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: AppMotion.tab,
                curve: AppMotion.softSpring,
                child: AnimatedSwitcher(
                  duration: AppMotion.quick,
                  switchInCurve: AppMotion.emphasizedDecelerate,
                  switchOutCurve: AppMotion.emphasizedAccelerate,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: Icon(
                    selected ? selectedIcon : icon,
                    key: ValueKey(selected),
                    color: color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: AppMotion.tab,
                curve: AppMotion.emphasized,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  fontFamily: 'PlusJakartaSans',
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
