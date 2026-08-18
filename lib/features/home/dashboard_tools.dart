import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../converters/convert_catalog.dart';

const _kDashboardToolsKey = 'dashboard_tool_ids_v7';

/// Not on Shortcuts: Scan = FAB.
const kDashboardPinnedIds = <DashboardToolId>{DashboardToolId.smartScan};

/// All tools that can appear on the Home shortcut strip.
enum DashboardToolId {
  smartScan,
  pdfTools,
  importImages,
  files,
  tags,
  favorites,
  trash,
  qrReader,
  pdfToTxt,
  pdfToDocx,
  txtToPdf,
  pptxToPdf,
  docxToPdf,
  xlsxToCsv,
  xlsxToPdf,
  imageFormats,

  /// Legacy — migrated to [imageFormats].
  editImages,
}

/// Default shortcut tiles — Scan/Convert via FAB + Convert tab.
const kDefaultDashboardTools = <DashboardToolId>[
  DashboardToolId.importImages,
  DashboardToolId.pdfTools,
  DashboardToolId.qrReader,
  DashboardToolId.favorites,
  DashboardToolId.imageFormats,
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

/// Customize-sheet catalog — shortcuts only (pinned actions omitted).
const kDashboardToolCatalog = <DashboardToolMeta>[
  DashboardToolMeta(
    id: DashboardToolId.importImages,
    label: 'Import',
    icon: Icons.collections_outlined,
    color: Color(0xFF1565C0),
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
    id: DashboardToolId.qrReader,
    label: 'QR reader',
    icon: Icons.qr_code_scanner,
    color: Color(0xFF2F6F7E),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pdfTools,
    label: 'PDF Tools',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFC62828),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pdfToTxt,
    label: 'PDF to .txt',
    icon: Icons.article_outlined,
    color: Color(0xFF1565C0),
  ),
  DashboardToolMeta(
    id: DashboardToolId.pdfToDocx,
    label: 'PDF to DOCX',
    icon: Icons.description_outlined,
    color: Color(0xFF0277BD),
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
    id: DashboardToolId.docxToPdf,
    label: 'DOCX to PDF',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFF1565C0),
  ),
  DashboardToolMeta(
    id: DashboardToolId.xlsxToCsv,
    label: 'XLSX to CSV',
    icon: Icons.table_chart_outlined,
    color: Color(0xFF2E7D32),
  ),
  DashboardToolMeta(
    id: DashboardToolId.xlsxToPdf,
    label: 'XLSX to PDF',
    icon: Icons.grid_on_outlined,
    color: Color(0xFF558B2F),
  ),
  DashboardToolMeta(
    id: DashboardToolId.imageFormats,
    label: 'Edit photo',
    icon: Icons.photo_outlined,
    color: Color(0xFFEF6C00),
  ),
];

DashboardToolMeta? metaForTool(DashboardToolId id) {
  for (final m in kDashboardToolCatalog) {
    if (m.id == id) return m;
  }
  return switch (id) {
    DashboardToolId.smartScan => const DashboardToolMeta(
      id: DashboardToolId.smartScan,
      label: 'Smart Scan',
      icon: Icons.document_scanner_outlined,
      color: AppTheme.navy,
    ),
    DashboardToolId.pdfTools => const DashboardToolMeta(
      id: DashboardToolId.pdfTools,
      label: 'PDF Tools',
      icon: Icons.picture_as_pdf_outlined,
      color: Color(0xFFC62828),
    ),
    _ => null,
  };
}

/// Map dashboard convert shortcuts → Convert hub tool id.
ConvertToolId? convertToolIdForDashboard(DashboardToolId id) => switch (id) {
  DashboardToolId.pdfTools => ConvertToolId.pdfTools,
  DashboardToolId.pdfToTxt => ConvertToolId.pdfToTxt,
  DashboardToolId.pdfToDocx => ConvertToolId.pdfToDocx,
  DashboardToolId.txtToPdf => ConvertToolId.txtToPdf,
  DashboardToolId.pptxToPdf => ConvertToolId.pptxToPdf,
  DashboardToolId.docxToPdf => ConvertToolId.docxToPdf,
  DashboardToolId.xlsxToCsv => ConvertToolId.xlsxToCsv,
  DashboardToolId.xlsxToPdf => ConvertToolId.xlsxToPdf,
  DashboardToolId.imageFormats ||
  DashboardToolId.editImages => ConvertToolId.imageFormats,
  _ => null,
};

List<DashboardToolId> sanitizeDashboardTools(Iterable<DashboardToolId> ids) {
  final out = <DashboardToolId>[];
  for (final id in ids) {
    // Edit images merged into Images.
    final resolved = id == DashboardToolId.editImages
        ? DashboardToolId.imageFormats
        : id;
    if (resolved == DashboardToolId.files) continue;
    if (kDashboardPinnedIds.contains(resolved)) continue;
    if (out.contains(resolved)) continue;
    out.add(resolved);
  }
  if (out.isEmpty) return List.of(kDefaultDashboardTools);
  return out;
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
    var fromV7 = true;
    var raw = prefs.getStringList(_kDashboardToolsKey);
    // Migrate older keys.
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v6');
    }
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v5');
    }
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v4');
    }
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v3');
    }
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v2');
    }
    if (raw == null || raw.isEmpty) {
      fromV7 = false;
      raw = prefs.getStringList('dashboard_tool_ids_v1');
    }
    if (raw == null || raw.isEmpty) return;

    final allowed = DashboardToolId.values.map((e) => e.name).toSet();
    final parsed = <DashboardToolId>[];
    for (final s in raw) {
      if (s == 'cropImage' ||
          s == 'resizeImage' ||
          s == 'compressImage' ||
          s == 'editImages') {
        if (!parsed.contains(DashboardToolId.imageFormats)) {
          parsed.add(DashboardToolId.imageFormats);
        }
        continue;
      }
      if (s == 'pngToJpg' ||
          s == 'jpgToPng' ||
          s == 'toWebp' ||
          s == 'toGif' ||
          s == 'heicToJpg') {
        if (!parsed.contains(DashboardToolId.imageFormats)) {
          parsed.add(DashboardToolId.imageFormats);
        }
        continue;
      }
      if (!allowed.contains(s)) continue;
      for (final id in DashboardToolId.values) {
        if (id.name == s) {
          parsed.add(id);
          break;
        }
      }
    }

    if (!fromV7) {
      // Files is bottom nav; Import becomes a shortcut tile (Start card gone).
      parsed.removeWhere((id) => id == DashboardToolId.files);
      if (!parsed.contains(DashboardToolId.importImages)) {
        parsed.insert(0, DashboardToolId.importImages);
      }
      if (!parsed.contains(DashboardToolId.pdfTools)) {
        final i = parsed.indexOf(DashboardToolId.importImages);
        parsed.insert(i >= 0 ? i + 1 : 0, DashboardToolId.pdfTools);
      }
    }

    final cleaned = sanitizeDashboardTools(parsed);
    state = cleaned;
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kDashboardToolsKey,
      state.map((e) => e.name).toList(),
    );
  }

  Future<void> add(DashboardToolId id) async {
    if (kDashboardPinnedIds.contains(id)) return;
    if (state.contains(id)) return;
    state = [...state, id];
    await _persist();
  }

  Future<void> remove(DashboardToolId id) async {
    if (state.length <= 1) return;
    if (!state.contains(id)) return;
    state = state.where((e) => e != id).toList();
    await _persist();
  }

  Future<void> setAll(List<DashboardToolId> ids) async {
    state = sanitizeDashboardTools(ids);
    await _persist();
  }

  Future<void> resetDefaults() async {
    state = List.of(kDefaultDashboardTools);
    await _persist();
  }
}
