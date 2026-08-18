import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Destinations that can sit in the two inner nav slots (beside Scan).
enum NavDest {
  editPhoto,
  convert,
  favorites,
  pdfTools;

  String get label => switch (this) {
    editPhoto => 'Edit photo',
    convert => 'Convert',
    favorites => 'Favorites',
    pdfTools => 'PDF Tools',
  };

  String get navLabel => switch (this) {
    editPhoto => 'Photo',
    convert => 'Convert',
    favorites => 'Favorites',
    pdfTools => 'PDF',
  };

  IconData get icon => switch (this) {
    editPhoto => Icons.photo_outlined,
    convert => Icons.swap_horiz,
    favorites => Icons.bookmark_border,
    pdfTools => Icons.picture_as_pdf_outlined,
  };

  IconData get selectedIcon => switch (this) {
    editPhoto => Icons.photo,
    convert => Icons.swap_horiz,
    favorites => Icons.bookmark,
    pdfTools => Icons.picture_as_pdf,
  };
}

const _kLeftKey = 'nav_inner_left';
const _kRightKey = 'nav_inner_right';

class NavSlots {
  const NavSlots({required this.innerLeft, required this.innerRight});

  final NavDest innerLeft;
  final NavDest innerRight;

  static const defaults = NavSlots(
    innerLeft: NavDest.editPhoto,
    innerRight: NavDest.convert,
  );
}

final navSlotsProvider = StateNotifierProvider<NavSlotsController, NavSlots>(
  (ref) => NavSlotsController(),
);

class NavSlotsController extends StateNotifier<NavSlots> {
  NavSlotsController() : super(NavSlots.defaults) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NavSlots(
      innerLeft: _parse(prefs.getString(_kLeftKey), NavDest.editPhoto),
      innerRight: _parse(prefs.getString(_kRightKey), NavDest.convert),
    );
  }

  Future<void> setInnerLeft(NavDest dest) async {
    if (dest == state.innerRight) return;
    state = NavSlots(innerLeft: dest, innerRight: state.innerRight);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLeftKey, dest.name);
  }

  Future<void> setInnerRight(NavDest dest) async {
    if (dest == state.innerLeft) return;
    state = NavSlots(innerLeft: state.innerLeft, innerRight: dest);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRightKey, dest.name);
  }

  static NavDest _parse(String? raw, NavDest fallback) {
    return NavDest.values.firstWhere(
      (d) => d.name == raw,
      orElse: () => fallback,
    );
  }
}
