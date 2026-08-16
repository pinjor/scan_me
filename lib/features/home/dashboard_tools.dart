import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';

const _kDashboardToolsKey = 'dashboard_tool_ids_v2';

/// All tools that can appear on the Home dashboard grid.
enum DashboardToolId {
  smartScan,
  pdfTools, // labeled “Convert” — opens Tools hub
  importImages,
  files,
  tags,
  favorites,
  trash,
  pdfToTxt,
  txtToPdf,
  pptxToPdf,
  pngToJpg,
  jpgToPng,
}

/// Default visible tools (most important).
const kDefaultDashboardTools = <DashboardToolId>[
  DashboardToolId.smartScan,
  DashboardToolId.pdfTools,
  DashboardToolId.importImages,
  DashboardToolId.files,
];

class DashboardToolMeta {
  const DashboardToolMeta({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });

  final DashboardToolId id;
  final String label;
  final IconData icon;
  final Color color;
}

/// Full catalog (order = Add-sheet order).
const kDashboardToolCatalog = <DashboardToolMeta>[
  DashboardToolMeta(
    id: DashboardToolId.smartScan,
    label: 'Smart Scan',
    icon: Icons.document_scanner_outlined,
    color: AppTheme.navy,
  ),
  DashboardToolMeta(
    id: DashboardToolId.pdfTools,
    label: 'Convert',
    icon: Icons.swap_horiz,
    color: Color(0xFFEF6C00),
  ),
  DashboardToolMeta(
    id: DashboardToolId.importImages,
    label: 'Import Images',
    icon: Icons.collections_outlined,
    color: Color(0xFF1565C0),
  ),
  DashboardToolMeta(
    id: DashboardToolId.files,
    label: 'Files',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFF455A64),
  ),
  DashboardToolMeta(
    id: DashboardToolId.tags,
    label: 'Tags',
    icon: Icons.local_offer_outlined,
    color: Color(0xFF6A1B9A),
  ),
  DashboardToolMeta(
    id: DashboardToolId.favorites,
    label: 'Favorites',
    icon: Icons.bookmark_border,
    color: Color(0xFFF9A825),
  ),
  DashboardToolMeta(
    id: DashboardToolId.trash,
    label: 'Trash',
    icon: Icons.delete_outline,
    color: Color(0xFFC62828),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pdfToTxt,
    label: 'PDF to .txt',
    icon: Icons.article_outlined,
    color: Color(0xFF1565C0),
  ),
  DashboardToolMeta(
    id: DashboardToolId.txtToPdf,
    label: '.txt to PDF',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFC62828),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pptxToPdf,
    label: 'PPTX to PDF',
    icon: Icons.present_to_all_outlined,
    color: Color(0xFFEF6C00),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pngToJpg,
    label: 'PNG to JPG',
    icon: Icons.image_outlined,
    color: Color(0xFF2E7D32),
  ),
  DashboardToolMeta(
    id: DashboardToolId.jpgToPng,
    label: 'JPG to PNG',
    icon: Icons.crop_original,
    color: Color(0xFF6A1B9A),
  ),
];

DashboardToolMeta? metaForTool(DashboardToolId id) {
  for (final m in kDashboardToolCatalog) {
    if (m.id == id) return m;
  }
  return null;
}

final dashboardToolsProvider =
    StateNotifierProvider<DashboardToolsController, List<DashboardToolId>>(
  (ref) => DashboardToolsController(),
);

class DashboardToolsController extends StateNotifier<List<DashboardToolId>> {
  DashboardToolsController() : super(List.of(kDefaultDashboardTools)) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getStringList(_kDashboardToolsKey);
    // Migrate v1 → v2 (drop folders / unfiled / settings).
    if (raw == null || raw.isEmpty) {
      raw = prefs.getStringList('dashboard_tool_ids_v1');
    }
    if (raw == null || raw.isEmpty) return;
    final allowed = DashboardToolId.values.map((e) => e.name).toSet();
    final parsed = <DashboardToolId>[];
    for (final s in raw) {
      if (!allowed.contains(s)) continue;
      for (final id in DashboardToolId.values) {
        if (id.name == s) {
          parsed.add(id);
          break;
        }
      }
    }
    if (parsed.isNotEmpty) {
      state = parsed;
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDashboardToolsKey,
      state.map((e) => e.name).toList(),
    );
  }

  Future<void> add(DashboardToolId id) async {
    if (state.contains(id)) return;
    state = [...state, id];
    await _persist();
  }

  Future<void> remove(DashboardToolId id) async {
    if (state.length <= 1) return; // keep at least one
    if (!state.contains(id)) return;
    state = state.where((e) => e != id).toList();
    await _persist();
  }

  Future<void> setAll(List<DashboardToolId> ids) async {
    final unique = <DashboardToolId>[];
    for (final id in ids) {
      if (!unique.contains(id)) unique.add(id);
    }
    if (unique.isEmpty) unique.addAll(kDefaultDashboardTools);
    state = unique;
    await _persist();
  }

  Future<void> resetDefaults() async {
    state = List.of(kDefaultDashboardTools);
    await _persist();
  }
}
