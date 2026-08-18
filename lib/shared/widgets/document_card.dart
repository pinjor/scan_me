import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../models/library_models.dart';
import '../models/scanned_document.dart';
import 'app_transitions.dart';
import 'app_ui.dart';

class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.doc,
    required this.onOpen,
    required this.onMore,
    this.onFavorite,
    this.onDelete,
    this.folderName,
    this.tagDefs = const [],
  });

  final ScannedDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;
  final String? folderName;
  final List<TagDef> tagDefs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = doc.pdfPath != null ? 'PDF' : 'Images';
    final date = _friendlyDate(doc.updatedAt);
    // Compact meta: pages · type · relative date (size via More / Activity).
    final meta = [
      '${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
      type,
      date,
    ].join(' · ');
    final byId = {for (final t in tagDefs) t.id: t};

    final card = LibraryFileCard(
      name: doc.name,
      meta: meta,
      onOpen: onOpen,
      onMore: onMore,
      heroTag: 'doc-thumb-${doc.id}',
      isFavorite: doc.isFavorite,
      onFavorite: onFavorite,
      tagChips: [
        if (folderName != null) MetaChip(label: folderName!),
        for (final id in doc.tags.take(2))
          MetaChip(
            label: byId[id]?.name ?? id,
            color: byId[id] != null ? Color(byId[id]!.color) : null,
          ),
      ],
      thumbnail:
          doc.thumbnailPath != null && File(doc.thumbnailPath!).existsSync()
          ? Image.file(
              File(doc.thumbnailPath!),
              fit: BoxFit.cover,
              cacheWidth: 160,
              filterQuality: FilterQuality.medium,
            )
          : Center(
              child: Icon(
                Icons.description_outlined,
                color: scheme.onSurfaceVariant,
                size: 24,
              ),
            ),
    );

    if (onDelete == null) return card;

    return Dismissible(
      key: ValueKey(doc.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete!();
        return false;
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

  String _friendlyDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Updated today';
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Updated yesterday';
    }
    if (now.difference(d).inDays < 7) {
      return 'Updated ${DateFormat('EEEE').format(d)}';
    }
    return 'Updated ${DateFormat('MMM d').format(d)}';
  }
}

/// Compact library row — thumb + title + quiet more. Favorite lives on the thumb.
class LibraryFileCard extends StatelessWidget {
  const LibraryFileCard({
    super.key,
    required this.name,
    required this.meta,
    required this.thumbnail,
    required this.onOpen,
    required this.onMore,
    this.heroTag,
    this.isFavorite = false,
    this.onFavorite,
    this.tagChips = const [],
  });

  final String name;
  final String meta;
  final Widget thumbnail;
  final VoidCallback onOpen;
  final VoidCallback onMore;
  final Object? heroTag;
  final bool isFavorite;
  final VoidCallback? onFavorite;
  final List<Widget> tagChips;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$name, $meta',
      child: AppCard(
        onTap: onOpen,
        elevated: true,
        bordered: true,
        padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FileThumb(
              heroTag: heroTag,
              isFavorite: isFavorite,
              onFavorite: onFavorite,
              child: thumbnail,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                      _QuietIconButton(
                        icon: Icons.more_vert,
                        tooltip: 'More actions',
                        onPressed: onMore,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (tagChips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(spacing: 4, runSpacing: 4, children: tagChips),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileThumb extends StatelessWidget {
  const _FileThumb({
    required this.child,
    required this.isFavorite,
    this.heroTag,
    this.onFavorite,
  });

  final Widget child;
  final Object? heroTag;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 70,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest),
            Positioned.fill(child: child),
            if (onFavorite != null)
              Positioned(
                right: 3,
                bottom: 3,
                child: _ThumbFavorite(
                  isFavorite: isFavorite,
                  onPressed: onFavorite!,
                ),
              ),
          ],
        ),
      ),
    );
    if (heroTag != null) {
      thumb = Hero(tag: heroTag!, child: thumb);
    }
    return thumb;
  }
}

class _ThumbFavorite extends StatelessWidget {
  const _ThumbFavorite({required this.isFavorite, required this.onPressed});

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isFavorite ? 'Remove from favorites' : 'Favorite',
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isFavorite ? Icons.bookmark : Icons.bookmark_border,
              size: 13,
              color: isFavorite ? AppTheme.warning : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietIconButton extends StatelessWidget {
  const _QuietIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
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
    _ctrl = AnimationController(vsync: this, duration: AppMotion.chip);
    _t = CurvedAnimation(
      parent: _ctrl,
      curve: AppMotion.emphasizedDecelerate,
      reverseCurve: AppMotion.emphasizedAccelerate,
    );
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
                          icon: Icons.swap_horiz,
                          background: scheme.surface,
                          foreground: scheme.primary,
                          onPressed: () => _run(widget.onConverters!),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SpeedDialAction(
                        label: 'Images to PDF',
                        icon: Icons.collections_outlined,
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
              duration: AppMotion.chip,
              curve: AppMotion.softSpring,
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
