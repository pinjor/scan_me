import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../models/scanned_document.dart';
import 'app_ui.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.doc,
    required this.onOpen,
    required this.onMore,
    this.onDelete,
  });

  final ScannedDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final type = doc.pdfPath != null ? 'PDF' : 'Images';
    final size = doc.fileSizeBytes != null
        ? _formatBytes(doc.fileSizeBytes!)
        : null;
    final date = _friendlyDate(doc.updatedAt);
    final chips = <String>[
      '${doc.pageCount} ${doc.pageCount == 1 ? 'Page' : 'Pages'}',
      type,
      ?size,
      date,
    ];

    final card = AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'doc-thumb-${doc.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 84,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: doc.thumbnailPath != null &&
                        File(doc.thumbnailPath!).existsSync()
                    ? Image.file(
                        File(doc.thumbnailPath!),
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.description_outlined,
                        color: scheme.onSurfaceVariant,
                        size: 28,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  doc.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips.map((c) => MetaChip(label: c)).toList(),
                ),
              ],
            ),
          ),
          AppCircleIconButton(
            icon: Icons.more_horiz,
            tooltip: 'Document options',
            size: 44,
            onPressed: onMore,
          ),
        ],
      ),
    );

    if (onDelete == null) return card;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete!();
        return false; // parent handles delete + list refresh
      },
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: scheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Icon(Icons.delete_outline, color: scheme.error, size: 28),
      ),
      child: card,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    if (now.difference(d).inDays < 7) {
      return DateFormat('EEEE').format(d);
    }
    return DateFormat('MMM d').format(d);
  }
}

/// Expandable FAB: Images to PDF (secondary) + Scan Document (primary).
class ScanFabMenu extends StatefulWidget {
  const ScanFabMenu({
    super.key,
    required this.onScan,
    required this.onImagesToPdf,
  });

  final VoidCallback onScan;
  final VoidCallback onImagesToPdf;

  @override
  State<ScanFabMenu> createState() => _ScanFabMenuState();
}

class _ScanFabMenuState extends State<ScanFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _expand;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expand = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizeTransition(
          sizeFactor: _expand,
          axis: Axis.vertical,
          child: FadeTransition(
            opacity: _expand,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: 'images_to_pdf',
                onPressed: () {
                  if (_open) _toggle();
                  widget.onImagesToPdf();
                },
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
                elevation: 2,
                icon: const Icon(Icons.photo_library_outlined, size: 22),
                label: const Text('Images to PDF'),
              ),
            ),
          ),
        ),
        FloatingActionButton.extended(
          heroTag: 'new_scan',
          onPressed: () {
            if (_open) {
              widget.onScan();
              _toggle();
            } else {
              _toggle();
            }
          },
          icon: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: Icon(
              _open ? Icons.document_scanner_outlined : Icons.add,
              size: 22,
            ),
          ),
          label: Text(_open ? 'Scan Document' : 'New'),
        ),
      ],
    );
  }
}
