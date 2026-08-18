import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/app_transitions.dart';
import 'theme_spec.dart';

export 'theme_spec.dart';

const _kThemeModeKey = 'theme_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemeModeKey);
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

/// Offline scanner — Plus Jakarta Sans. Brand: navy + teal · warm paper.
abstract final class AppTheme {
  /// Primary navy (brand).
  static const Color navy = Color(0xFF1B3A4B);
  static const Color ink = Color(0xFF12202B);

  /// Secondary accent.
  static const Color accent = Color(0xFF2A7A86);

  /// Lighter navy for dark-mode buttons / FAB.
  static const Color navyOnDark = Color(0xFF7AADC0);

  /// Warm ivory — not flat grey.
  static const Color paper = Color(0xFFF4F0EA);

  /// Deep navy-black — not cheap OLED crush.
  static const Color paperDark = Color(0xFF0C1216);

  /// Lifted navy surface for cards on dark.
  static const Color surfaceDark = Color(0xFF151C22);
  static const Color success = Color(0xFF2E7D4F);
  static const Color warning = Color(0xFFC48A2A);
  static const Color info = Color(0xFF1565C0);
  static const Color scannerBg = Color(0xFF0A0A0A);

  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static List<BoxShadow> cardShadow({bool pressed = false}) => [
    BoxShadow(
      color: const Color(0xFF12202B).withValues(alpha: pressed ? 0.04 : 0.07),
      blurRadius: pressed ? 8 : 20,
      offset: Offset(0, pressed ? 2 : 8),
    ),
    BoxShadow(
      color: const Color(0xFF12202B).withValues(alpha: pressed ? 0.02 : 0.04),
      blurRadius: pressed ? 4 : 6,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> floatShadow() => [
    BoxShadow(
      color: const Color(0xFF12202B).withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFF12202B).withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  /// Spacing scale (logical px).
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;
  static const double space3xl = 32;

  /// Comfortable tap height (≥48 a11y); denser than prior redesign.
  static const double tapMin = 48;
  static const double iconTap = 44;

  static const String _font = 'PlusJakartaSans';

  static ThemeData light([ThemeSpec? spec]) {
    spec ??= kBuiltinThemes.first;
    if (spec.brand) {
      final scheme = ColorScheme.light(
        primary: navy,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDDE8EE),
        onPrimaryContainer: navy,
        secondary: accent,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFD4E8EC),
        onSecondaryContainer: navy,
        surface: const Color(0xFFFFFBF7),
        onSurface: ink,
        onSurfaceVariant: const Color(0xFF5A534C),
        outline: const Color(0xFFD4CBC2),
        outlineVariant: const Color(0xFFE8E0D6),
        error: const Color(0xFFB42318),
        surfaceContainerHighest: const Color(0xFFEBE4DB),
        surfaceContainerHigh: const Color(0xFFF3EDE6),
        surfaceContainerLow: const Color(0xFFFAF6F1),
      );
      return _base(scheme, Brightness.light, scaffoldBg: paper);
    }
    final scheme = spec.scheme(Brightness.light);
    return _base(scheme, Brightness.light, scaffoldBg: scheme.surface);
  }

  static ThemeData dark([ThemeSpec? spec]) {
    spec ??= kBuiltinThemes.first;
    if (spec.brand) {
      final scheme = ColorScheme.dark(
        primary: navyOnDark,
        onPrimary: ink,
        primaryContainer: navy,
        onPrimaryContainer: const Color(0xFFD5E3EA),
        secondary: const Color(0xFF7AADC0),
        onSecondary: ink,
        secondaryContainer: const Color(0xFF1E3F48),
        onSecondaryContainer: const Color(0xFFD4E8EC),
        surface: surfaceDark,
        onSurface: const Color(0xFFF3EEE8),
        onSurfaceVariant: const Color(0xFFB8C0C6),
        outline: const Color(0xFF3A4650),
        outlineVariant: const Color(0xFF243038),
        error: const Color(0xFFF04438),
        surfaceContainerHighest: const Color(0xFF1E272E),
        surfaceContainerHigh: const Color(0xFF1A2228),
        surfaceContainerLow: const Color(0xFF11181C),
      );
      return _base(scheme, Brightness.dark, scaffoldBg: paperDark);
    }
    final scheme = spec.scheme(Brightness.dark);
    return _base(scheme, Brightness.dark, scaffoldBg: scheme.surface);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness, {
    required Color scaffoldBg,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _font,
    );
    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            fontSize: 40,
            height: 1.15,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            fontSize: 32,
            height: 1.2,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            fontSize: 28,
            height: 1.25,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            fontSize: 22,
            height: 1.2,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            fontSize: 26,
            height: 1.15,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            fontSize: 17,
            height: 1.25,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.3,
          ),
          titleSmall: base.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            height: 1.3,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.4,
            fontSize: 15,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.4,
            fontSize: 14,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
            fontSize: 13,
          ),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.05,
            fontSize: 15,
            height: 1.2,
          ),
          labelMedium: base.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          labelSmall: base.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          // Caption-scale for meta (maps to bodySmall size with quieter weight).
        )
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          fontFamily: _font,
        );

    final isLight = brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _font,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 26),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 26),
        toolbarHeight: 60,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 8 : 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, tapMin),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, tapMin),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: 0.7),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, tapMin),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        sizeConstraints: const BoxConstraints.tightFor(width: 58, height: 58),
        shape: const CircleBorder(),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainerHighest,
        labelStyle: textTheme.labelMedium!.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        selectedShadowColor: Colors.transparent,
        checkmarkColor: scheme.onPrimary,
        showCheckmark: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.onSurfaceVariant;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: isLight ? 0.55 : 0.4,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleSize: const Size(44, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        minVerticalPadding: 14,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        minLeadingWidth: 40,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        textStyle: textTheme.titleMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final p in TargetPlatform.values)
            p: const _ScanMePageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _ScanMePageTransitionsBuilder extends PageTransitionsBuilder {
  const _ScanMePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.emphasized,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.12, 0),
      ).animate(outgoing),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.22, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
