import 'dart:convert';

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

class ScannedPage {
  ScannedPage({
    required this.id,
    required this.originalImagePath,
    this.processedImagePath,
    this.selectedFilter = PageFilter.original,
    required this.pageIndex,
    this.rotation = 0,
  });

  final String id;
  String originalImagePath;
  String? processedImagePath;
  PageFilter selectedFilter;
  int pageIndex;
  int rotation;

  /// Path used for preview/export (processed if filter applied).
  String get displayPath =>
      processedImagePath ?? originalImagePath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalImagePath': originalImagePath,
    'processedImagePath': processedImagePath,
    'selectedFilter': selectedFilter.wire,
    'pageIndex': pageIndex,
    'rotation': rotation,
  };

  factory ScannedPage.fromJson(Map<String, dynamic> json) => ScannedPage(
    id: json['id'] as String,
    originalImagePath: json['originalImagePath'] as String,
    processedImagePath: json['processedImagePath'] as String?,
    selectedFilter: PageFilterX.fromWire(json['selectedFilter'] as String?),
    pageIndex: json['pageIndex'] as int? ?? 0,
    rotation: json['rotation'] as int? ?? 0,
  );

  ScannedPage copyWith({
    String? id,
    String? originalImagePath,
    String? processedImagePath,
    PageFilter? selectedFilter,
    int? pageIndex,
    int? rotation,
    bool clearProcessed = false,
  }) => ScannedPage(
    id: id ?? this.id,
    originalImagePath: originalImagePath ?? this.originalImagePath,
    processedImagePath: clearProcessed
        ? null
        : (processedImagePath ?? this.processedImagePath),
    selectedFilter: selectedFilter ?? this.selectedFilter,
    pageIndex: pageIndex ?? this.pageIndex,
    rotation: rotation ?? this.rotation,
  );
}

class ScannedDocument {
  ScannedDocument({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.pages,
    this.thumbnailPath,
    this.pdfPath,
    this.exportImagePaths = const [],
    this.fileSizeBytes,
  });

  final String id;
  String name;
  final DateTime createdAt;
  DateTime updatedAt;
  List<ScannedPage> pages;
  String? thumbnailPath;
  String? pdfPath;
  List<String> exportImagePaths;
  int? fileSizeBytes;

  int get pageCount => pages.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'pages': pages.map((p) => p.toJson()).toList(),
    'thumbnailPath': thumbnailPath,
    'pdfPath': pdfPath,
    'exportImagePaths': exportImagePaths,
    'fileSizeBytes': fileSizeBytes,
  };

  factory ScannedDocument.fromJson(Map<String, dynamic> json) =>
      ScannedDocument(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        pages: (json['pages'] as List<dynamic>)
            .map((e) => ScannedPage.fromJson(e as Map<String, dynamic>))
            .toList(),
        thumbnailPath: json['thumbnailPath'] as String?,
        pdfPath: json['pdfPath'] as String?,
        exportImagePaths:
            (json['exportImagePaths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        fileSizeBytes: json['fileSizeBytes'] as int?,
      );

  String toJsonString() => jsonEncode(toJson());

  factory ScannedDocument.fromJsonString(String raw) =>
      ScannedDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
