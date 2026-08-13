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
    this.folderName,
  });

  final ScannedDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final VoidCallback? onDelete;
  final String? folderName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final type = doc.pdfPath != null ? 'PDF' : 'Images';
    final size = doc.fileSizeBytes != null
        ? _formatBytes(doc.fileSizeBytes!)
        : null;
    final date = _friendlyDate(doc.updatedAt);
    final meta = [
      '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
      type,
      if (size != null) size,
      date,
    ].join(' · ');
    final badges = <String>[
      if (folderName != null) folderName!,
      ...doc.tags.take(2),
    ];

    final card = AppCard(
      onTap: onOpen,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Hero(
            tag: 'doc-thumb-${doc.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 52,
                height: 68,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    doc.thumbnailPath != null &&
                            File(doc.thumbnailPath!).existsSync()
                        ? Image.file(
                            File(doc.thumbnailPath!),
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.description_outlined,
                            color: scheme.onSurfaceVariant,
                            size: 26,
                          ),
                    if (doc.isFavorite)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            size: 11,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children:
                        badges.map((c) => MetaChip(label: c)).toList(),
                  ),
                ],
              ],
            ),
          ),
          AppCircleIconButton(
            icon: Icons.more_horiz,
            tooltip: 'Document options',
            size: 40,
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
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Icon(Icons.delete_outline, color: scheme.error, size: 24),
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

/// Speed-dial FAB: fixed circular trigger; actions stack above, right-aligned.
class ScanFabMenu extends StatefulWidget {
  const ScanFabMenu({
    super.key,
    required this.onScan,
    required this.onImagesToPdf,
    this.onConverters,
  });

  final VoidCallback onScan;
  final VoidCallback onImagesToPdf;
  final VoidCallback? onConverters;

  @override
  State<ScanFabMenu> createState() => _ScanFabMenuState();
}

class _ScanFabMenuState extends State<ScanFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _t;
  var _open = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
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

  void _run(VoidCallback action) {
    if (_open) _toggle();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Keep dial pinned to the FAB's right edge (SizeTransition defaults to center).
    return Align(
      alignment: Alignment.bottomRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: _t,
            axis: Axis.vertical,
            alignment: Alignment.bottomRight,
            // Critical: keep expanding panel flush right, not centered.
            child: Align(
              alignment: Alignment.centerRight,
              child: FadeTransition(
                opacity: _t,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (widget.onConverters != null) ...[
                        _SpeedDialAction(
                          label: 'Converters',
                          icon: Icons.auto_awesome_outlined,
                          background: scheme.surface,
                          foreground: scheme.primary,
                          onPressed: () => _run(widget.onConverters!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SpeedDialAction(
                        label: 'Images to PDF',
                        icon: Icons.photo_library_outlined,
                        background: scheme.surface,
                        foreground: scheme.primary,
                        onPressed: () => _run(widget.onImagesToPdf),
                      ),
                      const SizedBox(height: 12),
                      _SpeedDialAction(
                        label: 'Scan Document',
                        icon: Icons.document_scanner_outlined,
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                        onPressed: () => _run(widget.onScan),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          FloatingActionButton(
            heroTag: 'fab_menu_toggle',
            tooltip: _open ? 'Close' : 'New',
            onPressed: _toggle,
            child: AnimatedRotation(
              turns: _open ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(_open ? Icons.close : Icons.add, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedDialAction extends StatelessWidget {
  const _SpeedDialAction({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Material(
          color: scheme.surface,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: text.labelLarge?.copyWith(color: scheme.onSurface),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            heroTag: 'fab_$label',
            tooltip: label,
            backgroundColor: background,
            foregroundColor: foreground,
            elevation: 2,
            onPressed: onPressed,
            child: Icon(icon, size: 24),
          ),
        ),
      ],
    );
  }
}
