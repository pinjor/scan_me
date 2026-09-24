import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_surface.dart';
import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_transitions.dart';

/// All · Favorites · Tagged · Deleted + sort.
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
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 2),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  key: const Key('library-filter-bar'),
                  height: 30,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.65,
                    ),
                    borderRadius: BorderRadius.circular(8),
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
                        label: 'Tagged',
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
              SizedBox(
                width: 32,
                height: 30,
                child: PopupMenuButton<LibrarySort>(
                  tooltip: 'Sort: ${query.sort.label}',
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: Icon(
                    Icons.sort,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  initialValue: query.sort,
                  onSelected: n.setSort,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  itemBuilder: (_) => [
                    for (final s in LibrarySort.values)
                      PopupMenuItem<LibrarySort>(
                        value: s,
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              child: query.sort == s
                                  ? Icon(
                                      Icons.check,
                                      size: 15,
                                      color: scheme.primary,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.15,
                                fontWeight: query.sort == s
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: query.sort == s
                                    ? scheme.primary
                                    : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
                  child: tags.isEmpty
                      ? Text(
                          'No tags yet.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in tags)
                              FilterChip(
                                visualDensity: const VisualDensity(
                                  horizontal: -4,
                                  vertical: -4,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                labelPadding: const EdgeInsets.only(right: 6),
                                selected: query.tag == tag.id,
                                avatar: CircleAvatar(
                                  backgroundColor: Color(tag.color),
                                  radius: 5,
                                ),
                                label: Text(
                                  tag.name,
                                  style: TextStyle(
                                    fontSize: 11,
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
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 2),
            child: Text(
              'Kept until auto-remove.',
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
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                height: 1.0,
                color: selected ? scheme.onPrimary : scheme.onSurface,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
