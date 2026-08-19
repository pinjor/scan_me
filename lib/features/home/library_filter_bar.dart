import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_surface.dart';
import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_transitions.dart';

/// All · Favorites · Tags · Deleted + sort. Tag chips wrap when Tags is on.
class LibraryFilterBar extends ConsumerWidget {
  const LibraryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(libraryQueryProvider);
    final tagsAsync = ref.watch(tagsProvider);
    final docs = ref.watch(documentsProvider).valueOrNull ?? const [];
    final converts = kScanOnlySurface
        ? const <ConvertOutput>[]
        : (ref.watch(convertOutputsProvider).valueOrNull ?? const []);
    final catalog = tagsAsync.valueOrNull ?? const <TagDef>[];
    final usedIds = {
      ...collectAllTags(docs),
      for (final c in converts) ...c.tags,
    };
    final tags = catalog.where((t) => usedIds.contains(t.id)).toList();
    final scheme = Theme.of(context).colorScheme;
    final n = ref.read(libraryQueryProvider.notifier);

    final allOn =
        !query.showTrash &&
        !query.favoritesOnly &&
        !query.tagsPickerOpen &&
        query.tag == null;
    final favOn = query.favoritesOnly && !query.showTrash;
    final tagsOn =
        !query.showTrash && (query.tagsPickerOpen || query.tag != null);
    final deletedOn = query.showTrash;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  key: const Key('library-filter-bar'),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    children: [
                      _Seg(label: 'All', selected: allOn, onTap: n.showAll),
                      _Seg(
                        label: 'Favorites',
                        selected: favOn,
                        onTap: n.showFavorites,
                      ),
                      _Seg(
                        label: 'Tags',
                        selected: tagsOn,
                        onTap: () {
                          if (tagsOn) {
                            n.showAll();
                          } else {
                            n.showTagsPicker();
                          }
                        },
                      ),
                      _Seg(
                        label: 'Deleted',
                        selected: deletedOn,
                        onTap: () => n.setShowTrash(true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<LibrarySort>(
                tooltip: query.sort.label,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.sort, size: 22),
                initialValue: query.sort,
                onSelected: n.setSort,
                itemBuilder: (_) => [
                  for (final s in LibrarySort.values)
                    CheckedPopupMenuItem(
                      value: s,
                      checked: query.sort == s,
                      child: Text(s.label),
                    ),
                ],
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: AppMotion.chip,
          curve: AppMotion.emphasizedDecelerate,
          alignment: Alignment.topCenter,
          child: tagsOn && !deletedOn
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: tags.isEmpty
                      ? Text(
                          'No tags yet. Add them from a document’s ⋯ menu.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in tags)
                              FilterChip(
                                visualDensity: VisualDensity.compact,
                                selected: query.tag == tag.id,
                                avatar: CircleAvatar(
                                  backgroundColor: Color(tag.color),
                                  radius: 7,
                                ),
                                label: Text(
                                  tag.name,
                                  style: TextStyle(
                                    color: query.tag == tag.id
                                        ? Colors.white
                                        : scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selectedColor: Color(tag.color),
                                checkmarkColor: Colors.white,
                                onSelected: (sel) =>
                                    n.setTag(sel ? tag.id : null),
                              ),
                          ],
                        ),
                )
              : const SizedBox.shrink(),
        ),
        if (deletedOn)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text(
              'Documents stay here until they are automatically removed.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: FilterChip(
        visualDensity: const VisualDensity(horizontal: -2, vertical: -4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        labelPadding: EdgeInsets.zero,
        selectedColor: scheme.primary,
        backgroundColor: Colors.transparent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        label: SizedBox(
          width: double.infinity,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
