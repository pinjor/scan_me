import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/models/scanned_document.dart';

/// Bottom sheet: toggle catalog tags on a document + create new colored tag.
Future<void> showDocumentTagsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ScannedDocument doc,
  VoidCallback? onChanged,
}) {
  return _showTagsSheet(
    context: context,
    selectedOf: (ref) {
      final latest =
          ref
              .watch(documentsProvider)
              .valueOrNull
              ?.where((d) => d.id == doc.id)
              .firstOrNull ??
          doc;
      return latest.tags.toSet();
    },
    onToggle: (ref, tagId) async {
      await ref.read(documentsProvider.notifier).toggleTag(doc.id, tagId);
      onChanged?.call();
    },
    onCreated: (ref, created) async {
      await ref.read(documentsProvider.notifier).addTag(doc.id, created.id);
      onChanged?.call();
    },
  );
}

Future<void> showConvertTagsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required ConvertOutput output,
}) {
  return _showTagsSheet(
    context: context,
    selectedOf: (ref) {
      final latest =
          ref
              .watch(convertOutputsProvider)
              .valueOrNull
              ?.where((c) => c.path == output.path)
              .firstOrNull ??
          output;
      return latest.tags.toSet();
    },
    onToggle: (ref, tagId) =>
        ref.read(convertOutputsProvider.notifier).toggleTag(output.path, tagId),
    onCreated: (ref, created) => ref
        .read(convertOutputsProvider.notifier)
        .addTag(output.path, created.id),
  );
}

Future<void> _showTagsSheet({
  required BuildContext context,
  required Set<String> Function(WidgetRef ref) selectedOf,
  required Future<void> Function(WidgetRef ref, String tagId) onToggle,
  required Future<void> Function(WidgetRef ref, TagDef created) onCreated,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: Consumer(
          builder: (ctx, ref, _) {
            final tags =
                ref.watch(tagsProvider).valueOrNull ?? const <TagDef>[];
            final selected = selectedOf(ref);

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tags', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to add or remove. Manage colors in Settings.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in tags)
                            FilterChip(
                              selected: selected.contains(tag.id),
                              label: Text(tag.name),
                              avatar: CircleAvatar(
                                backgroundColor: Color(tag.color),
                                radius: 8,
                              ),
                              selectedColor: Color(
                                tag.color,
                              ).withValues(alpha: 0.28),
                              checkmarkColor: Color(tag.color),
                              onSelected: (_) => onToggle(ref, tag.id),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('New tag'),
                            onPressed: () async {
                              final created = await showCreateOrEditTagDialog(
                                context: ctx,
                                ref: ref,
                              );
                              if (created != null) {
                                await onCreated(ref, created);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

Future<TagDef?> showCreateOrEditTagDialog({
  required BuildContext context,
  required WidgetRef ref,
  TagDef? existing,
}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var color = existing?.color ?? kTagColorPalette.first;
  final result = await showDialog<TagDef?>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(existing == null ? 'New tag' : 'Edit tag'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. Education',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Color', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in kTagColorPalette)
                        GestureDetector(
                          onTap: () => setLocal(() => color = c),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c
                                    ? Theme.of(ctx).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: Text('Delete “${existing.name}”?'),
                        content: const Text(
                          'Removes this tag from Settings and from every document.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref.read(tagsProvider.notifier).delete(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx, null);
                  },
                  child: Text(
                    'Delete',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  try {
                    if (existing == null) {
                      final tag = await ref
                          .read(tagsProvider.notifier)
                          .create(name, color);
                      if (ctx.mounted) Navigator.pop(ctx, tag);
                    } else {
                      await ref
                          .read(tagsProvider.notifier)
                          .update(existing.id, name: name, color: color);
                      if (ctx.mounted) {
                        Navigator.pop(
                          ctx,
                          TagDef(
                            id: existing.id,
                            name: name,
                            color: color,
                            createdAt: existing.createdAt,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: Text(existing == null ? 'Create' : 'Save'),
              ),
            ],
          );
        },
      );
    },
  );
  nameCtrl.dispose();
  return result;
}
