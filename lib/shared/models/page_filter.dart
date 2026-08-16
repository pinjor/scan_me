enum PageFilter {
  original,
  blackAndWhite,
  grayscale,
  autoEnhance,
  vivid,
  lighten,
}

extension PageFilterX on PageFilter {
  String get wire => switch (this) {
        PageFilter.original => 'original',
        PageFilter.blackAndWhite => 'blackAndWhite',
        PageFilter.grayscale => 'grayscale',
        PageFilter.autoEnhance => 'autoEnhance',
        PageFilter.vivid => 'vivid',
        PageFilter.lighten => 'lighten',
      };

  String get label => switch (this) {
        PageFilter.original => 'Original',
        PageFilter.blackAndWhite => 'B&W',
        PageFilter.grayscale => 'Greyscale',
        PageFilter.autoEnhance => 'Auto',
        PageFilter.vivid => 'Vivid',
        PageFilter.lighten => 'Lighten',
      };

  String get enhanceTitle => switch (this) {
        PageFilter.original => 'Original',
        PageFilter.blackAndWhite => 'Black & white',
        PageFilter.grayscale => 'Greyscale',
        PageFilter.autoEnhance => 'Auto enhance',
        PageFilter.vivid => 'Vivid color',
        PageFilter.lighten => 'Lighten',
      };

  /// Preview hint in enhance sheet (not exact pipeline).
  bool get previewAsGrey =>
      this == PageFilter.blackAndWhite || this == PageFilter.grayscale;

  bool get isProcessed => this != PageFilter.original;

  static PageFilter fromWire(String? v) => switch (v) {
        'blackAndWhite' => PageFilter.blackAndWhite,
        'grayscale' => PageFilter.grayscale,
        'autoEnhance' => PageFilter.autoEnhance,
        'vivid' => PageFilter.vivid,
        'lighten' => PageFilter.lighten,
        _ => PageFilter.original,
      };
}
