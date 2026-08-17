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
  /// Hub tile that opens JPG / PNG / WebP / GIF / HEIC stacked.
  imageFormats,
  toJpg,
  toPng,
  toWebp,
  toGif,
  heicToJpg,
  /// Hub tile that opens Crop / Resize / Compress stacked.
  editImages,
  crop,
  resize,
  compress,
}

enum ConvertSectionId { documents, images, edit }

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
    title: 'Images',
    blurb: 'Switch photo formats for sharing or editing',
  ),
  ConvertSectionMeta(
    id: ConvertSectionId.edit,
    title: 'Edit images',
    blurb: 'Crop, resize, or make files smaller for sharing',
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
    title: 'Image formats',
    subtitle: 'JPG, PNG, WebP, GIF, HEIC',
    icon: Icons.image_outlined,
    color: Color(0xFFEF6C00),
    progressLabel: 'Converting…',
    steps: [
      'Pick a format',
      'Choose a photo',
      'Save or share',
    ],
  ),
  ConvertToolMeta(
    id: ConvertToolId.editImages,
    section: ConvertSectionId.edit,
    title: 'Edit images',
    subtitle: 'Crop, resize, or reduce file size',
    icon: Icons.photo_filter,
    color: Color(0xFF455A64),
    progressLabel: 'Editing…',
    steps: [
      'Pick a tool',
      'Choose a photo',
      'Save or share',
    ],
  ),
];

/// JPG / PNG / WebP / GIF / HEIC — stacked in [ImageFormatsHubScreen].
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

/// Crop / Resize / Compress — stacked in [ImageEditHubScreen].
const kEditImageTools = <ConvertToolMeta>[
  ConvertToolMeta(
    id: ConvertToolId.crop,
    section: ConvertSectionId.edit,
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
    section: ConvertSectionId.edit,
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
    section: ConvertSectionId.edit,
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
  for (final m in kConvertTools) {
    if (m.id == id) return m;
  }
  for (final m in kImageFormatTools) {
    if (m.id == id) return m;
  }
  for (final m in kEditImageTools) {
    if (m.id == id) return m;
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
    ConvertToolId.compress =>
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
  };
}
