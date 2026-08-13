import 'dart:convert';

/// Built-in starter folders (user can add more).
const kDefaultFolderNames = [
  'Work',
  'Personal',
  'Receipts',
  'IDs',
  'Certificates',
  'Finance',
];

class DocFolder {
  DocFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DocFolder.fromJson(Map<String, dynamic> json) => DocFolder(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

enum LibrarySort {
  recentlyModified,
  recentlyCreated,
  nameAsc,
  nameDesc,
  pageCount,
  fileSize,
}

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
        LibrarySort.recentlyModified => 'Recently modified',
        LibrarySort.recentlyCreated => 'Recently created',
        LibrarySort.nameAsc => 'Name A–Z',
        LibrarySort.nameDesc => 'Name Z–A',
        LibrarySort.pageCount => 'Number of pages',
        LibrarySort.fileSize => 'File size',
      };
}

enum PdfQualityPreset { small, balanced, high }

extension PdfQualityPresetX on PdfQualityPreset {
  String get label => switch (this) {
        PdfQualityPreset.small => 'Small size',
        PdfQualityPreset.balanced => 'Balanced',
        PdfQualityPreset.high => 'High quality',
      };

  int get maxLongEdge => switch (this) {
        PdfQualityPreset.small => 1200,
        PdfQualityPreset.balanced => 1600,
        PdfQualityPreset.high => 2400,
      };

  int get jpegQuality => switch (this) {
        PdfQualityPreset.small => 68,
        PdfQualityPreset.balanced => 82,
        PdfQualityPreset.high => 92,
      };
}

enum PdfPageSizeOption { original, a4, letter }

extension PdfPageSizeOptionX on PdfPageSizeOption {
  String get label => switch (this) {
        PdfPageSizeOption.original => 'Original',
        PdfPageSizeOption.a4 => 'A4',
        PdfPageSizeOption.letter => 'Letter',
      };
}

enum PdfOrientationOption { auto, portrait, landscape }

extension PdfOrientationOptionX on PdfOrientationOption {
  String get label => switch (this) {
        PdfOrientationOption.auto => 'Auto',
        PdfOrientationOption.portrait => 'Portrait',
        PdfOrientationOption.landscape => 'Landscape',
      };
}

enum ImageExportFormat { jpg, png }

enum ImageExportQuality { low, medium, high }

extension ImageExportQualityX on ImageExportQuality {
  String get label => switch (this) {
        ImageExportQuality.low => 'Low',
        ImageExportQuality.medium => 'Medium',
        ImageExportQuality.high => 'High',
      };

  int get jpegQuality => switch (this) {
        ImageExportQuality.low => 55,
        ImageExportQuality.medium => 82,
        ImageExportQuality.high => 95,
      };

  int get maxLongEdge => switch (this) {
        ImageExportQuality.low => 1000,
        ImageExportQuality.medium => 1600,
        ImageExportQuality.high => 2400,
      };
}

enum ImageExportScope { currentPage, selectedPages, entireDocument }

extension ImageExportScopeX on ImageExportScope {
  String get label => switch (this) {
        ImageExportScope.currentPage => 'Current page',
        ImageExportScope.selectedPages => 'Selected pages',
        ImageExportScope.entireDocument => 'Entire document',
      };
}

class ExportSettings {
  ExportSettings({
    this.createPdf = true,
    this.saveImages = false,
    this.pdfQuality = PdfQualityPreset.balanced,
    this.pdfPageSize = PdfPageSizeOption.original,
    this.pdfOrientation = PdfOrientationOption.auto,
    this.imageFormat = ImageExportFormat.jpg,
    this.imageQuality = ImageExportQuality.medium,
    this.imageScope = ImageExportScope.entireDocument,
    this.selectedPageIndexes = const {},
    this.currentPageIndex = 0,
  });

  bool createPdf;
  bool saveImages;
  PdfQualityPreset pdfQuality;
  PdfPageSizeOption pdfPageSize;
  PdfOrientationOption pdfOrientation;
  ImageExportFormat imageFormat;
  ImageExportQuality imageQuality;
  ImageExportScope imageScope;
  Set<int> selectedPageIndexes;
  int currentPageIndex;
}

/// Future-ready home-screen widget actions (no platform widgets yet).
abstract final class ScanMeWidgetBridge {
  static const androidScanNowAction = 'app.atl.scanme.action.SCAN_NOW';
  static const iosNewScanUrl = 'scanme://new-scan';

  /// Deep-link / intent entry points widgets should open.
  static Uri get newScanDeepLink => Uri.parse(iosNewScanUrl);

  static Map<String, dynamic> describeFutureWidgets() => {
        'android': {
          'type': 'glance_or_remoteviews',
          'actions': [androidScanNowAction],
          'status': 'architecture_ready',
        },
        'ios': {
          'type': 'widgetkit',
          'url': iosNewScanUrl,
          'status': 'architecture_ready',
        },
      };

  static String catalogJson() => jsonEncode(describeFutureWidgets());
}
