import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum PdfToolId {
  merge,
  split,
  reorder,
  deletePages,
  rotate,
  extract,
  pdfToImages,
  imagesToPdf,
  compress,
}

enum PdfToolGroup { organize, convert, optimize }

class PdfToolMeta {
  const PdfToolMeta({
    required this.id,
    required this.group,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.steps,
  });

  final PdfToolId id;
  final PdfToolGroup group;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<String> steps;
}

const kPdfToolGroups = <({PdfToolGroup id, String title, String blurb})>[
  (
    id: PdfToolGroup.organize,
    title: 'Organize PDF',
    blurb: 'Merge, split, reorder, and clean pages',
  ),
  (
    id: PdfToolGroup.convert,
    title: 'Convert PDF',
    blurb: 'Pages to images, or images to a PDF',
  ),
  (
    id: PdfToolGroup.optimize,
    title: 'Optimize PDF',
    blurb: 'Shrink a large file without leaving this phone',
  ),
];

const kPdfTools = <PdfToolMeta>[
  PdfToolMeta(
    id: PdfToolId.merge,
    group: PdfToolGroup.organize,
    title: 'Merge PDFs',
    subtitle: 'Combine several PDFs into one',
    icon: Icons.merge_type,
    color: Color(0xFF1565C0),
    steps: ['Choose PDFs', 'Reorder', 'Merge'],
  ),
  PdfToolMeta(
    id: PdfToolId.split,
    group: PdfToolGroup.organize,
    title: 'Split PDF',
    subtitle: 'Break one PDF into smaller files',
    icon: Icons.call_split,
    color: Color(0xFF6A1B9A),
    steps: ['Choose PDF', 'Pick pages or ranges', 'Split'],
  ),
  PdfToolMeta(
    id: PdfToolId.reorder,
    group: PdfToolGroup.organize,
    title: 'Reorder pages',
    subtitle: 'Drag pages into a new order',
    icon: Icons.swap_vert,
    color: Color(0xFF00838F),
    steps: ['Choose PDF', 'Drag pages', 'Save as new PDF'],
  ),
  PdfToolMeta(
    id: PdfToolId.deletePages,
    group: PdfToolGroup.organize,
    title: 'Delete pages',
    subtitle: 'Remove pages and keep the rest',
    icon: Icons.delete_outline,
    color: Color(0xFFC62828),
    steps: ['Choose PDF', 'Select pages', 'Save as new PDF'],
  ),
  PdfToolMeta(
    id: PdfToolId.rotate,
    group: PdfToolGroup.organize,
    title: 'Rotate pages',
    subtitle: 'Turn pages 90° or 180°',
    icon: Icons.rotate_right,
    color: Color(0xFFEF6C00),
    steps: ['Choose PDF', 'Rotate', 'Save as new PDF'],
  ),
  PdfToolMeta(
    id: PdfToolId.extract,
    group: PdfToolGroup.organize,
    title: 'Extract pages',
    subtitle: 'Copy selected pages into a new PDF',
    icon: Icons.content_copy_outlined,
    color: Color(0xFF2E7D32),
    steps: ['Choose PDF', 'Select pages', 'Extract'],
  ),
  PdfToolMeta(
    id: PdfToolId.pdfToImages,
    group: PdfToolGroup.convert,
    title: 'PDF to images',
    subtitle: 'Export pages as JPG or PNG',
    icon: Icons.image_outlined,
    color: Color(0xFF5D4037),
    steps: ['Choose PDF', 'Pick pages and format', 'Export'],
  ),
  PdfToolMeta(
    id: PdfToolId.imagesToPdf,
    group: PdfToolGroup.convert,
    title: 'Images to PDF',
    subtitle: 'Turn photos into a multi-page PDF',
    icon: Icons.picture_as_pdf_outlined,
    color: AppTheme.navy,
    steps: ['Choose photos', 'Reorder', 'Create PDF'],
  ),
  PdfToolMeta(
    id: PdfToolId.compress,
    group: PdfToolGroup.optimize,
    title: 'Compress PDF',
    subtitle: 'Make a large PDF smaller to share',
    icon: Icons.compress,
    color: Color(0xFF455A64),
    steps: ['Choose PDF', 'Pick quality', 'Compress'],
  ),
];

PdfToolMeta pdfToolMeta(PdfToolId id) =>
    kPdfTools.firstWhere((t) => t.id == id);
