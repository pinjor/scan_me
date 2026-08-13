import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
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
    await prefs.setString(
      _kThemeModeKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}

/// Millennial work-app look: navy trust, paper surfaces, bundled Liberation fonts.
/// Fully offline — no runtime font fetch.
abstract final class AppTheme {
  static const Color navy = Color(0xFF1B3A4B);
  static const Color ink = Color(0xFF243447);
  static const Color accent = Color(0xFF2F6F7E);
  static const Color paper = Color(0xFFF0F2F5);
  static const Color paperDark = Color(0xFF161B22);
  static const Color surfaceDark = Color(0xFF1E2530);

  static const String _sans = 'LiberationSans';
  static const String _serif = 'LiberationSerif';

  static ThemeData light() {
    final scheme = ColorScheme.light(
      primary: navy,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD6E2EA),
      onPrimaryContainer: navy,
      secondary: accent,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: const Color(0xFF5A6570),
      outline: const Color(0xFFC8D0D8),
      outlineVariant: const Color(0xFFE2E7EC),
      error: const Color(0xFFB42318),
      surfaceContainerHighest: const Color(0xFFE8ECF0),
    );
    return _base(scheme, Brightness.light).copyWith(
      scaffoldBackgroundColor: paper,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: const Color(0xFF8FB4C4),
      onPrimary: const Color(0xFF0D1F28),
      primaryContainer: const Color(0xFF2A3F4C),
      onPrimaryContainer: const Color(0xFFD6E2EA),
      secondary: const Color(0xFF7BA8B4),
      onSecondary: const Color(0xFF0D1F28),
      surface: surfaceDark,
      onSurface: const Color(0xFFE8ECF0),
      onSurfaceVariant: const Color(0xFFA8B2BC),
      outline: const Color(0xFF3D4854),
      outlineVariant: const Color(0xFF2C3540),
      error: const Color(0xFFF04438),
      surfaceContainerHighest: const Color(0xFF2A3340),
    );
    return _base(scheme, Brightness.dark).copyWith(
      scaffoldBackgroundColor: paperDark,
    );
  }

  static ThemeData _base(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: _sans,
    );
    final textTheme = base.textTheme
        .copyWith(
          displayLarge: base.textTheme.displayLarge?.copyWith(
            fontFamily: _serif,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          displayMedium: base.textTheme.displayMedium?.copyWith(
            fontFamily: _serif,
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: base.textTheme.headlineLarge?.copyWith(
            fontFamily: _serif,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            fontFamily: _serif,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontFamily: _serif,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontFamily: _sans,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontFamily: _sans,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
          bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.35),
          labelLarge: base.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        )
        .apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: _sans,
      textTheme: textTheme,
      dividerColor: scheme.outlineVariant,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.brightness == Brightness.light
            ? paper
            : paperDark,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 1,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.brightness == Brightness.light
            ? Colors.white
            : surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return navy;
          return scheme.outlineVariant;
        }),
      ),
    );
  }
}
