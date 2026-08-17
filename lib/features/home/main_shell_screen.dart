import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../converters/converters_hub_screen.dart';
import '../settings/settings_screen.dart';
import 'home_dashboard_screen.dart';
import 'home_flows.dart';
import 'home_screen.dart';

/// Bottom nav shell: Home · Files · Camera FAB · Convert · Me.
class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  var _index = 0;
  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _index) return;
    // Drop keyboard / search focus before leaving a tab (KeepAlive keeps nodes).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _index = i);
    if (AppMotion.reduce(context)) {
      _pageController.jumpToPage(i);
    } else {
      _pageController.animateToPage(
        i,
        duration: AppMotion.tab,
        curve: AppMotion.emphasizedDecelerate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fabColor = isDark ? AppTheme.navyOnDark : AppTheme.navy;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) {
          FocusManager.instance.primaryFocus?.unfocus();
          if (_index != i) setState(() => _index = i);
        },
        children: [
          _KeepAlivePage(
            child: HomeDashboardScreen(
              isActive: _index == 0,
              onOpenFiles: () => _go(1),
              onOpenTools: () => _go(2),
            ),
          ),
          _KeepAlivePage(
            child: HomeScreen(
              embedded: true,
              isActive: _index == 1,
              onOpenTools: () => _go(2),
            ),
          ),
          const _KeepAlivePage(child: ConvertersHubScreen(embedded: true)),
          const _KeepAlivePage(child: SettingsScreen(embedded: true)),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FadeRiseIn(
        offset: 8,
        scaleFrom: 0.9,
        child: Semantics(
          button: true,
          label: 'Scan Document',
          child: FloatingActionButton(
            onPressed: () => HomeFlows.startScan(context),
            tooltip: 'Scan Document',
            backgroundColor: fabColor,
            foregroundColor: scheme.onPrimary,
            elevation: 6,
            highlightElevation: 10,
            shape: const CircleBorder(),
            child: const Icon(Icons.document_scanner, size: 30),
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 64,
        padding: EdgeInsets.zero,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        color: scheme.surface,
        child: Row(
          children: [
            Expanded(
              child: _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Home',
                selected: _index == 0,
                onTap: () => _go(0),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.inventory_2_outlined,
                selectedIcon: Icons.inventory_2_rounded,
                label: 'Files',
                selected: _index == 1,
                onTap: () => _go(1),
              ),
            ),
            const SizedBox(width: 64),
            Expanded(
              child: _NavItem(
                icon: Icons.swap_horiz,
                selectedIcon: Icons.swap_horiz,
                label: 'Convert',
                selected: _index == 2,
                onTap: () => _go(2),
              ),
            ),
            Expanded(
              child: _NavItem(
                icon: Icons.manage_accounts_outlined,
                selectedIcon: Icons.manage_accounts,
                label: 'Me',
                selected: _index == 3,
                onTap: () => _go(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
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
          height: 56,
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
                    size: 24,
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
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
