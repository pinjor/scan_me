import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kThemePresetKey = 'theme_preset';
const _kCustomKey = 'theme_custom_presets_v1';
const _kMaxCustom = 30;

enum ThemeKind { single, dual, triple }

enum ThemeStyle { tonal, vibrant, expressive, neutral, mono, rainbow }

extension ThemeStyleX on ThemeStyle {
  String get label => switch (this) {
    ThemeStyle.tonal => 'Tonal',
    ThemeStyle.vibrant => 'Vibrant',
    ThemeStyle.expressive => 'Expressive',
    ThemeStyle.neutral => 'Neutral',
    ThemeStyle.mono => 'Mono',
    ThemeStyle.rainbow => 'Rainbow',
  };

  DynamicSchemeVariant get variant => switch (this) {
    ThemeStyle.tonal => DynamicSchemeVariant.tonalSpot,
    ThemeStyle.vibrant => DynamicSchemeVariant.vibrant,
    ThemeStyle.expressive => DynamicSchemeVariant.expressive,
    ThemeStyle.neutral => DynamicSchemeVariant.neutral,
    ThemeStyle.mono => DynamicSchemeVariant.monochrome,
    ThemeStyle.rainbow => DynamicSchemeVariant.rainbow,
  };
}

extension ThemeKindX on ThemeKind {
  String get label => switch (this) {
    ThemeKind.single => 'Single',
    ThemeKind.dual => 'Dual',
    ThemeKind.triple => 'Triple',
  };
}

Color contrastingOn(Color background) {
  return background.computeLuminance() > 0.45
      ? const Color(0xFF12202B)
      : const Color(0xFFFFFFFF);
}

/// One Material 3 color story: 1–3 seeds + scheme variant.
class ThemeSpec {
  const ThemeSpec({
    required this.id,
    required this.name,
    required this.primary,
    this.secondary,
    this.tertiary,
    this.kind = ThemeKind.single,
    this.style = ThemeStyle.tonal,
    this.brand = false,
    this.custom = false,
  });

  final String id;
  final String name;
  final int primary;
  final int? secondary;
  final int? tertiary;
  final ThemeKind kind;
  final ThemeStyle style;
  final bool brand;
  final bool custom;

  Color get primaryColor => Color(primary);
  Color? get secondaryColor => secondary == null ? null : Color(secondary!);
  Color? get tertiaryColor => tertiary == null ? null : Color(tertiary!);

  List<Color> get swatches => [
    primaryColor,
    ?secondaryColor,
    ?tertiaryColor,
  ];

  /// HCT `fromSeed` remaps the swatch. Pin the colors the user tapped so
  /// FAB / chips / buttons match the studio card.
  ColorScheme scheme(Brightness brightness) {
    var out = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      dynamicSchemeVariant: style.variant,
    );
    out = out.copyWith(
      primary: primaryColor,
      onPrimary: contrastingOn(primaryColor),
      inversePrimary: primaryColor,
    );
    if (secondary != null) {
      final s = secondaryColor!;
      final seeded = ColorScheme.fromSeed(
        seedColor: s,
        brightness: brightness,
        dynamicSchemeVariant: style.variant,
      );
      out = out.copyWith(
        secondary: s,
        onSecondary: contrastingOn(s),
        secondaryContainer: seeded.primaryContainer,
        onSecondaryContainer: seeded.onPrimaryContainer,
      );
    }
    if (tertiary != null) {
      final t = tertiaryColor!;
      final seeded = ColorScheme.fromSeed(
        seedColor: t,
        brightness: brightness,
        dynamicSchemeVariant: style.variant,
      );
      out = out.copyWith(
        tertiary: t,
        onTertiary: contrastingOn(t),
        tertiaryContainer: seeded.primaryContainer,
        onTertiaryContainer: seeded.onPrimaryContainer,
      );
    }
    final wash = brightness == Brightness.light ? 0.08 : 0.16;
    out = out.copyWith(
      surface: Color.alphaBlend(
        primaryColor.withValues(alpha: wash),
        out.surface,
      ),
    );
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is ThemeSpec &&
      other.id == id &&
      other.name == name &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.tertiary == tertiary &&
      other.kind == kind &&
      other.style == style &&
      other.brand == brand &&
      other.custom == custom;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    primary,
    secondary,
    tertiary,
    kind,
    style,
    brand,
    custom,
  );

  ThemeSpec copyWith({
    String? id,
    String? name,
    int? primary,
    int? secondary,
    bool clearSecondary = false,
    int? tertiary,
    bool clearTertiary = false,
    ThemeKind? kind,
    ThemeStyle? style,
    bool? brand,
    bool? custom,
  }) => ThemeSpec(
    id: id ?? this.id,
    name: name ?? this.name,
    primary: primary ?? this.primary,
    secondary: clearSecondary ? null : (secondary ?? this.secondary),
    tertiary: clearTertiary ? null : (tertiary ?? this.tertiary),
    kind: kind ?? this.kind,
    style: style ?? this.style,
    brand: brand ?? this.brand,
    custom: custom ?? this.custom,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'primary': primary,
    'secondary': secondary,
    'tertiary': tertiary,
    'kind': kind.name,
    'style': style.name,
    'custom': custom,
  };

  static ThemeSpec fromJson(Map<String, Object?> json) {
    ThemeKind kind = ThemeKind.single;
    for (final k in ThemeKind.values) {
      if (k.name == json['kind']) kind = k;
    }
    ThemeStyle style = ThemeStyle.tonal;
    for (final s in ThemeStyle.values) {
      if (s.name == json['style']) style = s;
    }
    return ThemeSpec(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Custom',
      primary: (json['primary'] as num?)?.toInt() ?? 0xFF1B3A4B,
      secondary: (json['secondary'] as num?)?.toInt(),
      tertiary: (json['tertiary'] as num?)?.toInt(),
      kind: kind,
      style: style,
      custom: true,
    );
  }
}

class ThemeSelection {
  const ThemeSelection({required this.selectedId, this.custom = const []});

  final String selectedId;
  final List<ThemeSpec> custom;

  ThemeSpec get spec {
    for (final s in custom) {
      if (s.id == selectedId) return s;
    }
    for (final s in kBuiltinThemes) {
      if (s.id == selectedId) return s;
    }
    return kBuiltinThemes.first;
  }

  List<ThemeSpec> get all => [...kBuiltinThemes, ...custom];
}

final themeSelectionProvider =
    StateNotifierProvider<ThemeSelectionController, ThemeSelection>(
      (ref) => ThemeSelectionController(),
    );

/// Active spec — watch this for ThemeData rebuilds.
final themePresetProvider = Provider<ThemeSpec>(
  (ref) => ref.watch(themeSelectionProvider).spec,
);

class ThemeSelectionController extends StateNotifier<ThemeSelection> {
  ThemeSelectionController()
    : super(const ThemeSelection(selectedId: 'scanme')) {
    _load();
  }

  ThemeSelectionController.hydrated(super.initial);

  var _epoch = 0;

  static Future<ThemeSelection> hydrate() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = <ThemeSpec>[];
    final rawList = prefs.getString(_kCustomKey);
    if (rawList != null && rawList.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawList);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              custom.add(ThemeSpec.fromJson(item));
            } else if (item is Map) {
              custom.add(ThemeSpec.fromJson(Map<String, Object?>.from(item)));
            }
          }
        }
      } catch (_) {}
    }
    var id = prefs.getString(_kThemePresetKey) ?? 'scanme';
    final known = [...kBuiltinThemes, ...custom].any((s) => s.id == id);
    if (!known) id = 'scanme';
    return ThemeSelection(selectedId: id, custom: custom);
  }

  Future<void> _load() async {
    final epoch = _epoch;
    final next = await hydrate();
    if (epoch != _epoch) return;
    state = next;
  }

  Future<void> select(String id) async {
    _epoch++;
    state = ThemeSelection(selectedId: id, custom: state.custom);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePresetKey, id);
  }

  Future<void> saveCustom(ThemeSpec spec) async {
    _epoch++;
    final next = [...state.custom];
    final i = next.indexWhere((s) => s.id == spec.id);
    if (i >= 0) {
      next[i] = spec;
    } else {
      if (next.length >= _kMaxCustom) next.removeAt(0);
      next.add(spec);
    }
    state = ThemeSelection(selectedId: spec.id, custom: next);
    await _persist(next, spec.id);
  }

  Future<void> deleteCustom(String id) async {
    _epoch++;
    final next = state.custom.where((s) => s.id != id).toList();
    final selected = state.selectedId == id ? 'scanme' : state.selectedId;
    state = ThemeSelection(selectedId: selected, custom: next);
    await _persist(next, selected);
  }

  Future<void> _persist(List<ThemeSpec> custom, String selectedId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePresetKey, selectedId);
    await prefs.setString(
      _kCustomKey,
      jsonEncode(custom.map((s) => s.toJson()).toList()),
    );
  }
}

ThemeSpec newCustomDraft() => ThemeSpec(
  id: const Uuid().v4(),
  name: 'My theme',
  primary: 0xFF1B3A4B,
  kind: ThemeKind.single,
  style: ThemeStyle.tonal,
  custom: true,
);

/// Built-in catalog. IDs stable (prefs).
final kBuiltinThemes = <ThemeSpec>[
  const ThemeSpec(
    id: 'scanme',
    name: 'ScanMe',
    primary: 0xFF1B3A4B,
    secondary: 0xFF2A7A86,
    kind: ThemeKind.dual,
    brand: true,
  ),
  // Single — classic
  const ThemeSpec(id: 'ocean', name: 'Ocean', primary: 0xFF0F6C7A),
  const ThemeSpec(id: 'forest', name: 'Forest', primary: 0xFF2D6A4F),
  const ThemeSpec(id: 'sunset', name: 'Sunset', primary: 0xFFC45C26),
  const ThemeSpec(id: 'grape', name: 'Grape', primary: 0xFF6B4C9A),
  const ThemeSpec(id: 'slate', name: 'Slate', primary: 0xFF3D5A80),
  const ThemeSpec(id: 'ink', name: 'Ink', primary: 0xFF1F2937),
  const ThemeSpec(id: 'coral', name: 'Coral', primary: 0xFFE05A4F),
  const ThemeSpec(id: 'rose', name: 'Rose', primary: 0xFFC2185B),
  const ThemeSpec(id: 'amber', name: 'Amber', primary: 0xFFE6A817),
  const ThemeSpec(id: 'gold', name: 'Gold', primary: 0xFFC6A15B),
  const ThemeSpec(id: 'lime', name: 'Lime', primary: 0xFF5B8C2A),
  const ThemeSpec(id: 'mint', name: 'Mint', primary: 0xFF2A9D8F),
  const ThemeSpec(id: 'sky', name: 'Sky', primary: 0xFF1D6FA5),
  const ThemeSpec(id: 'indigo', name: 'Indigo', primary: 0xFF3F51B5),
  const ThemeSpec(id: 'violet', name: 'Violet', primary: 0xFF7C4DFF),
  const ThemeSpec(id: 'magenta', name: 'Magenta', primary: 0xFFAD1457),
  const ThemeSpec(id: 'coffee', name: 'Coffee', primary: 0xFF6F4E37),
  const ThemeSpec(id: 'sand', name: 'Sand', primary: 0xFFC2A878),
  const ThemeSpec(id: 'crimson', name: 'Crimson', primary: 0xFFB71C1C),
  const ThemeSpec(id: 'ice', name: 'Ice', primary: 0xFF4FC3F7),
  // Single — style variants
  const ThemeSpec(
    id: 'ocean_vibrant',
    name: 'Ocean Pulse',
    primary: 0xFF0F6C7A,
    style: ThemeStyle.vibrant,
  ),
  const ThemeSpec(
    id: 'sunset_expressive',
    name: 'Ember',
    primary: 0xFFC45C26,
    style: ThemeStyle.expressive,
  ),
  const ThemeSpec(
    id: 'ink_mono',
    name: 'Mono Ink',
    primary: 0xFF1F2937,
    style: ThemeStyle.mono,
  ),
  const ThemeSpec(
    id: 'slate_neutral',
    name: 'Quiet Slate',
    primary: 0xFF3D5A80,
    style: ThemeStyle.neutral,
  ),
  const ThemeSpec(
    id: 'grape_rainbow',
    name: 'Prism',
    primary: 0xFF6B4C9A,
    style: ThemeStyle.rainbow,
  ),
  const ThemeSpec(
    id: 'rose_vibrant',
    name: 'Hot Rose',
    primary: 0xFFC2185B,
    style: ThemeStyle.vibrant,
  ),
  const ThemeSpec(
    id: 'forest_expressive',
    name: 'Canopy',
    primary: 0xFF2D6A4F,
    style: ThemeStyle.expressive,
  ),
  const ThemeSpec(
    id: 'gold_neutral',
    name: 'Parchment',
    primary: 0xFFC6A15B,
    style: ThemeStyle.neutral,
  ),
  // Dual
  const ThemeSpec(
    id: 'navy_gold',
    name: 'Navy Gold',
    kind: ThemeKind.dual,
    primary: 0xFF1B3A4B,
    secondary: 0xFFC6A15B,
  ),
  const ThemeSpec(
    id: 'teal_coral',
    name: 'Teal Coral',
    kind: ThemeKind.dual,
    primary: 0xFF0F6C7A,
    secondary: 0xFFE05A4F,
  ),
  const ThemeSpec(
    id: 'forest_cream',
    name: 'Forest Cream',
    kind: ThemeKind.dual,
    primary: 0xFF2D6A4F,
    secondary: 0xFFC2A878,
  ),
  const ThemeSpec(
    id: 'grape_lime',
    name: 'Grape Lime',
    kind: ThemeKind.dual,
    primary: 0xFF6B4C9A,
    secondary: 0xFF5B8C2A,
  ),
  const ThemeSpec(
    id: 'ink_amber',
    name: 'Ink Amber',
    kind: ThemeKind.dual,
    primary: 0xFF1F2937,
    secondary: 0xFFE6A817,
  ),
  const ThemeSpec(
    id: 'ocean_sand',
    name: 'Ocean Sand',
    kind: ThemeKind.dual,
    primary: 0xFF0F6C7A,
    secondary: 0xFFC2A878,
  ),
  const ThemeSpec(
    id: 'rose_slate',
    name: 'Rose Slate',
    kind: ThemeKind.dual,
    primary: 0xFFC2185B,
    secondary: 0xFF3D5A80,
  ),
  const ThemeSpec(
    id: 'indigo_peach',
    name: 'Indigo Peach',
    kind: ThemeKind.dual,
    primary: 0xFF3F51B5,
    secondary: 0xFFE8A87C,
  ),
  const ThemeSpec(
    id: 'coffee_cream',
    name: 'Café',
    kind: ThemeKind.dual,
    primary: 0xFF6F4E37,
    secondary: 0xFFE8D5B7,
  ),
  const ThemeSpec(
    id: 'midnight_ice',
    name: 'Midnight Ice',
    kind: ThemeKind.dual,
    primary: 0xFF0C1216,
    secondary: 0xFF4FC3F7,
  ),
  const ThemeSpec(
    id: 'ember_smoke',
    name: 'Ember Smoke',
    kind: ThemeKind.dual,
    primary: 0xFFC45C26,
    secondary: 0xFF5A534C,
  ),
  const ThemeSpec(
    id: 'moss_clay',
    name: 'Moss Clay',
    kind: ThemeKind.dual,
    primary: 0xFF5B8C2A,
    secondary: 0xFFB85C38,
  ),
  const ThemeSpec(
    id: 'sky_gold',
    name: 'Sky Gold',
    kind: ThemeKind.dual,
    primary: 0xFF1D6FA5,
    secondary: 0xFFC6A15B,
    style: ThemeStyle.vibrant,
  ),
  const ThemeSpec(
    id: 'violet_mint',
    name: 'Violet Mint',
    kind: ThemeKind.dual,
    primary: 0xFF7C4DFF,
    secondary: 0xFF2A9D8F,
    style: ThemeStyle.expressive,
  ),
  // Triple
  const ThemeSpec(
    id: 'scanme_trio',
    name: 'ScanMe Trio',
    kind: ThemeKind.triple,
    primary: 0xFF1B3A4B,
    secondary: 0xFF2A7A86,
    tertiary: 0xFFC6A15B,
  ),
  const ThemeSpec(
    id: 'sunset_trio',
    name: 'Sunset Trio',
    kind: ThemeKind.triple,
    primary: 0xFFC45C26,
    secondary: 0xFFC2185B,
    tertiary: 0xFFE6A817,
  ),
  const ThemeSpec(
    id: 'aurora',
    name: 'Aurora',
    kind: ThemeKind.triple,
    primary: 0xFF0F6C7A,
    secondary: 0xFF6B4C9A,
    tertiary: 0xFF2A9D8F,
  ),
  const ThemeSpec(
    id: 'royal',
    name: 'Royal',
    kind: ThemeKind.triple,
    primary: 0xFF1B3A4B,
    secondary: 0xFFC6A15B,
    tertiary: 0xFFF4F0EA,
  ),
  const ThemeSpec(
    id: 'berry',
    name: 'Berry',
    kind: ThemeKind.triple,
    primary: 0xFF6B4C9A,
    secondary: 0xFFC2185B,
    tertiary: 0xFF1F2937,
  ),
  const ThemeSpec(
    id: 'tropic',
    name: 'Tropic',
    kind: ThemeKind.triple,
    primary: 0xFF5B8C2A,
    secondary: 0xFF0F6C7A,
    tertiary: 0xFFE05A4F,
  ),
  const ThemeSpec(
    id: 'dusk',
    name: 'Dusk',
    kind: ThemeKind.triple,
    primary: 0xFF3F51B5,
    secondary: 0xFFAD1457,
    tertiary: 0xFFE6A817,
  ),
  const ThemeSpec(
    id: 'studio',
    name: 'Studio',
    kind: ThemeKind.triple,
    primary: 0xFF1F2937,
    secondary: 0xFFB71C1C,
    tertiary: 0xFF9CA3AF,
    style: ThemeStyle.neutral,
  ),
];
