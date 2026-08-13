enum PageFilter { original, blackAndWhite }

extension PageFilterX on PageFilter {
  String get wire => switch (this) {
        PageFilter.original => 'original',
        PageFilter.blackAndWhite => 'blackAndWhite',
      };

  static PageFilter fromWire(String? v) => switch (v) {
        'blackAndWhite' => PageFilter.blackAndWhite,
        _ => PageFilter.original,
      };
}
