import 'dart:convert';

import 'page_filter.dart';

export 'page_filter.dart';

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

  String get displayPath => processedImagePath ?? originalImagePath;

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
  }) =>
      ScannedPage(
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
    this.folderId,
    this.tags = const [],
    this.isFavorite = false,
    this.deletedAt,
    this.exportedAt,
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

  /// Soft organization (null = Unfiled).
  String? folderId;
  List<String> tags;
  bool isFavorite;

  /// Soft-delete timestamp; non-null means in Trash.
  DateTime? deletedAt;
  DateTime? exportedAt;

  int get pageCount => pages.length;
  bool get isInTrash => deletedAt != null;

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
        'folderId': folderId,
        'tags': tags,
        'isFavorite': isFavorite,
        'deletedAt': deletedAt?.toIso8601String(),
        'exportedAt': exportedAt?.toIso8601String(),
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
        exportImagePaths: (json['exportImagePaths'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        fileSizeBytes: json['fileSizeBytes'] as int?,
        folderId: json['folderId'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        isFavorite: json['isFavorite'] as bool? ?? false,
        deletedAt: json['deletedAt'] != null
            ? DateTime.tryParse(json['deletedAt'] as String)
            : null,
        exportedAt: json['exportedAt'] != null
            ? DateTime.tryParse(json['exportedAt'] as String)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());

  factory ScannedDocument.fromJsonString(String raw) =>
      ScannedDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  ScannedDocument copyMeta({
    String? name,
    DateTime? updatedAt,
    String? folderId,
    List<String>? tags,
    bool? isFavorite,
    DateTime? deletedAt,
    DateTime? exportedAt,
    bool clearFolder = false,
    bool clearDeleted = false,
    String? thumbnailPath,
    String? pdfPath,
    List<String>? exportImagePaths,
    int? fileSizeBytes,
    List<ScannedPage>? pages,
  }) =>
      ScannedDocument(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        pages: pages ?? this.pages,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
        pdfPath: pdfPath ?? this.pdfPath,
        exportImagePaths: exportImagePaths ?? this.exportImagePaths,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        folderId: clearFolder ? null : (folderId ?? this.folderId),
        tags: tags ?? this.tags,
        isFavorite: isFavorite ?? this.isFavorite,
        deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
        exportedAt: exportedAt ?? this.exportedAt,
      );
}
