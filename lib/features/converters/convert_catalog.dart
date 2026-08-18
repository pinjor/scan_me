import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'document_converter_service.dart';

enum ConvertToolId {
  pdfToTxt,
  pdfToDocx,
  txtToPdf,
  pptxToPdf,
  docxToPdf,
  xlsxToCsv,
  xlsxToPdf,
  /// Hub tile — combined convert / crop / resize / compress ([ImageFormatsHubScreen]).
  imageFormats,
  toJpg,
  toPng,
  toWebp,
  toGif,
  heicToJpg,
  /// Legacy alias of [imageFormats].
  editImages,
  crop,
  resize,
  compress,
  /// Hub tile — merge / split / compress PDF tools.
  pdfTools,
}

enum ConvertSectionId { documents, images, pdfTools }

class ConvertToolMeta {
  const ConvertToolMeta({
    required this.id,
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.steps = const [],
    this.progressLabel = 'Converting…',
  });

  final ConvertToolId id;
  final ConvertSectionId section;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final String progressLabel;
}

class ConvertSectionMeta {
  const ConvertSectionMeta({
    required this.id,
    required this.title,
    required this.blurb,
  });

  final ConvertSectionId id;
  final String title;
  final String blurb;
}

const kConvertSections = <ConvertSectionMeta>[
  ConvertSectionMeta(
    id: ConvertSectionId.documents,
    title: 'Documents',
    blurb: 'Turn PDFs, Word, Excel, and slides into the format you need',
  ),
  ConvertSectionMeta(
    id: ConvertSectionId.images,
    title: 'Photo',
    blurb: 'Convert, crop, resize, or compress — one place',
  ),
  ConvertSectionMeta(
    id: ConvertSectionId.pdfTools,
    title: 'PDF Tools',
    blurb: 'Merge, split, compress, and edit pages on this phone',
  ),
];

const kConvertTools = <ConvertToolMeta>[
  ConvertToolMeta(
    id: ConvertToolId.pdfToTxt,
    section: ConvertSectionId.documents,
    title: 'PDF to .txt',
    subtitle: 'Extract text from a PDF',
    icon: Icons.article_outlined,
    color: Color(0xFF1565C0),
    progressLabel: 'Extracting text…',
    steps: [
      'Choose PDF',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.pdfToDocx,
    section: ConvertSectionId.documents,
    title: 'PDF to DOCX',
    subtitle: 'Make an editable Word file from PDF text',
    icon: Icons.description_outlined,
    color: Color(0xFF0277BD),
    progressLabel: 'Building Word file…',
    steps: [
      'Choose PDF',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.txtToPdf,
    section: ConvertSectionId.documents,
    title: '.txt to PDF',
    subtitle: 'Turn plain text into a PDF',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFC62828),
    progressLabel: 'Building PDF…',
    steps: [
      'Choose text file',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.pptxToPdf,
    section: ConvertSectionId.documents,
    title: 'PPTX to PDF',
    subtitle: 'Share slides as a PDF',
    icon: Icons.present_to_all_outlined,
    color: Color(0xFFEF6C00),
    progressLabel: 'Converting slides…',
    steps: [
      'Choose PowerPoint',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.docxToPdf,
    section: ConvertSectionId.documents,
    title: 'DOCX to PDF',
    subtitle: 'Share a Word file as a PDF',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFF1565C0),
    progressLabel: 'Building PDF…',
    steps: [
      'Choose Word file',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.xlsxToCsv,
    section: ConvertSectionId.documents,
    title: 'XLSX to CSV',
    subtitle: 'Export the first sheet as CSV',
    icon: Icons.table_chart_outlined,
    color: Color(0xFF2E7D32),
    progressLabel: 'Writing CSV…',
    steps: [
      'Choose Excel file',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.xlsxToPdf,
    section: ConvertSectionId.documents,
    title: 'XLSX to PDF',
    subtitle: 'Turn a spreadsheet into a PDF',
    icon: Icons.grid_on_outlined,
    color: Color(0xFF558B2F),
    progressLabel: 'Building PDF…',
    steps: [
      'Choose Excel file',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.imageFormats,
    section: ConvertSectionId.images,
    title: 'Edit photo',
    subtitle: 'Convert format · crop · resize · compress',
    icon: Icons.photo_outlined,
    color: Color(0xFFEF6C00),
    progressLabel: 'Working…',
    steps: [
      'Choose a photo',
      'Pick what to do',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.pdfTools,
    section: ConvertSectionId.pdfTools,
    title: 'PDF Tools',
    subtitle: 'Merge, split, rotate, compress, and more',
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFC62828),
    progressLabel: 'Working…',
    steps: [
      'Choose a tool',
      'Pick a PDF',
      'Save or share',
    ],
  ),
];

/// Legacy per-format metas (Open-with labels / IntentConvertKind).
const kImageFormatTools = <ConvertToolMeta>[
  ConvertToolMeta(
    id: ConvertToolId.toJpg,
    section: ConvertSectionId.images,
    title: 'Image to JPG',
    subtitle: 'Save photos as JPEG for everyday use',
    icon: Icons.image_outlined,
    color: Color(0xFFEF6C00),
    progressLabel: 'Writing JPG…',
    steps: [
      'Choose image',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.toPng,
    section: ConvertSectionId.images,
    title: 'Image to PNG',
    subtitle: 'Keep sharp edges and transparency',
    icon: Icons.photo_outlined,
    color: Color(0xFF6A1B9A),
    progressLabel: 'Writing PNG…',
    steps: [
      'Choose image',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.toWebp,
    section: ConvertSectionId.images,
    title: 'Image to WebP',
    subtitle: 'Smaller web-friendly image',
    icon: Icons.language,
    color: Color(0xFF00838F),
    progressLabel: 'Writing WebP…',
    steps: [
      'Choose image',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.toGif,
    section: ConvertSectionId.images,
    title: 'Image to GIF',
    subtitle: 'Save a still frame as GIF',
    icon: Icons.gif_box_outlined,
    color: Color(0xFFAD1457),
    progressLabel: 'Writing GIF…',
    steps: [
      'Choose image',
      'Convert',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.heicToJpg,
    section: ConvertSectionId.images,
    title: 'HEIC to JPG',
    subtitle: 'Convert iPhone photos for sharing',
    icon: Icons.phone_iphone,
    color: AppTheme.navy,
    progressLabel: 'Converting HEIC…',
    steps: [
      'Choose HEIC photo',
      'Convert',
      'Save or share',
    ],
  ),
];

/// Crop / Resize / Compress — opened from combined Images screen.
const kEditImageTools = <ConvertToolMeta>[
  ConvertToolMeta(
    id: ConvertToolId.crop,
    section: ConvertSectionId.images,
    title: 'Crop image',
    subtitle: 'Trim edges for a cleaner crop',
    icon: Icons.crop,
    color: Color(0xFF455A64),
    progressLabel: 'Cropping…',
    steps: [
      'Choose photo',
      'Adjust frame',
      'Apply',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.resize,
    section: ConvertSectionId.images,
    title: 'Resize pixels',
    subtitle: 'Shrink or enlarge without cropping',
    icon: Icons.photo_size_select_large,
    color: Color(0xFF1565C0),
    progressLabel: 'Resizing…',
    steps: [
      'Choose photo',
      'Set size',
      'Export',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.compress,
    section: ConvertSectionId.images,
    title: 'Reduce file size',
    subtitle: 'Make an image smaller for sharing',
    icon: Icons.compress,
    color: Color(0xFF6A1B9A),
    progressLabel: 'Compressing…',
    steps: [
      'Choose photo',
      'Pick target size',
      'Save',
    ],
  ),
];

ConvertToolMeta? convertToolMeta(ConvertToolId id) {
  final resolved =
      id == ConvertToolId.editImages ? ConvertToolId.imageFormats : id;
  for (final m in kConvertTools) {
    if (m.id == resolved) return m;
  }
  for (final m in kImageFormatTools) {
    if (m.id == resolved) return m;
  }
  for (final m in kEditImageTools) {
    if (m.id == resolved) return m;
  }
  return null;
}

Future<ConvertResult> runSimpleConvert(
  ConvertToolId id,
  String path,
) {
  return switch (id) {
    ConvertToolId.pdfToTxt => DocumentConverterService.pdfToTxt(path),
    ConvertToolId.pdfToDocx => DocumentConverterService.pdfToDocx(path),
    ConvertToolId.txtToPdf => DocumentConverterService.txtToPdf(path),
    ConvertToolId.pptxToPdf => DocumentConverterService.pptxToPdf(path),
    ConvertToolId.docxToPdf => DocumentConverterService.docxToPdf(path),
    ConvertToolId.xlsxToCsv => DocumentConverterService.xlsxToCsv(path),
    ConvertToolId.xlsxToPdf => DocumentConverterService.xlsxToPdf(path),
    ConvertToolId.toJpg => DocumentConverterService.imageToJpeg(path),
    ConvertToolId.toPng => DocumentConverterService.imageToPng(path),
    ConvertToolId.toWebp => DocumentConverterService.imageToWebp(path),
    ConvertToolId.toGif => DocumentConverterService.imageToGif(path),
    ConvertToolId.heicToJpg => DocumentConverterService.heicToJpeg(path),
    ConvertToolId.imageFormats ||
    ConvertToolId.editImages ||
    ConvertToolId.crop ||
    ConvertToolId.resize ||
    ConvertToolId.compress ||
    ConvertToolId.pdfTools =>
      throw UnsupportedError('Use dedicated tool screen'),
  };
}

(List<String> exts, String title) pickHintsFor(ConvertToolId id) {
  return switch (id) {
    ConvertToolId.pdfToTxt => (['pdf'], 'Select PDF'),
    ConvertToolId.pdfToDocx => (['pdf'], 'Select PDF'),
    ConvertToolId.txtToPdf => (['txt', 'text', 'md', 'log'], 'Select text file'),
    ConvertToolId.pptxToPdf => (['pptx'], 'Select PowerPoint'),
    ConvertToolId.docxToPdf => (['docx'], 'Select Word document'),
    ConvertToolId.xlsxToCsv || ConvertToolId.xlsxToPdf => (
        ['xlsx'],
        'Select Excel workbook',
      ),
    ConvertToolId.imageFormats ||
    ConvertToolId.toJpg ||
    ConvertToolId.toPng ||
    ConvertToolId.toWebp ||
    ConvertToolId.toGif => (
        ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'],
        'Select image',
      ),
    ConvertToolId.heicToJpg => (['heic', 'heif'], 'Select HEIC photo'),
    ConvertToolId.editImages ||
    ConvertToolId.crop ||
    ConvertToolId.resize ||
    ConvertToolId.compress => (
        ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif'],
        'Select image',
      ),
    ConvertToolId.pdfTools => (['pdf'], 'Select PDF'),
  };
}
