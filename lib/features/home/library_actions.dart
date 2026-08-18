import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/services/convert_outputs_service.dart';
import '../../shared/models/scanned_document.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../file_viewer/file_viewer_screen.dart';
import '../viewer/viewer_screen.dart';

Future<void> showConvertLibraryActions({
  required BuildContext context,
  required WidgetRef ref,
  required ConvertOutput output,
}) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              output.name,
              style: Theme.of(ctx).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              FileViewerScreen.open(context, output.path, title: output.name);
            },
          ),
          ListTile(
            leading: Icon(
              output.isFavorite ? Icons.bookmark : Icons.bookmark_border,
            ),
            title: Text(
              output.isFavorite ? 'Remove from favorites' : 'Favorite',
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await ref
                  .read(convertOutputsProvider.notifier)
                  .setFavorite(output.path, !output.isFavorite);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Tags'),
            onTap: () async {
              Navigator.pop(ctx);
              await showConvertTagsSheet(
                context: context,
                ref: ref,
                output: output,
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Remove from converts',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await ConvertOutputsService.delete(output.path);
              if (context.mounted) {
                await ref.read(convertOutputsProvider.notifier).refresh();
              }
            },
          ),
        ],
      );
    },
  );
}

Future<void> showLibraryDocActions({
  required BuildContext context,
  required WidgetRef ref,
  required ScannedDocument doc,
  required bool trash,
}) {
  return trash
      ? _showTrashActions(context, ref, doc)
      : _showActions(context, ref, doc);
}

Future<void> _showActions(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument doc,
) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              doc.name,
              style: Theme.of(ctx).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Open'),
            onTap: () {
              Navigator.pop(ctx);
              AppPageRoute.push(context, ViewerScreen(documentId: doc.id));
            },
          ),
          ListTile(
            leading: Icon(
              doc.isFavorite ? Icons.bookmark : Icons.bookmark_border,
            ),
            title: Text(doc.isFavorite ? 'Remove from favorites' : 'Favorite'),
            onTap: () async {
              Navigator.pop(ctx);
              await ref
                  .read(documentsProvider.notifier)
                  .setFavorite(doc.id, !doc.isFavorite);
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('Tags'),
            onTap: () async {
              Navigator.pop(ctx);
              await showDocumentTagsSheet(context: context, ref: ref, doc: doc);
            },
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Rename'),
            onTap: () async {
              Navigator.pop(ctx);
              await renameLibraryDoc(context, ref, doc);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () async {
              Navigator.pop(ctx);
              await shareLibraryDoc(context, doc);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Move to Trash',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () async {
              Navigator.pop(ctx);
              await moveLibraryDocToTrash(context, ref, doc);
            },
          ),
        ],
      );
    },
  );
}

Future<void> _showTrashActions(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument doc,
) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('Restore'),
          onTap: () async {
            Navigator.pop(ctx);
            await ref.read(documentsProvider.notifier).restore(doc.id);
          },
        ),
        ListTile(
          leading: Icon(
            Icons.delete_forever,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            'Delete permanently',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await showConfirmSheet(
              context: context,
              title: 'Delete permanently?',
              message:
                  '“${doc.name}” will be removed forever. This cannot be undone.',
              confirmLabel: 'Delete permanently',
            );
            if (ok) {
              await ref
                  .read(documentsProvider.notifier)
                  .permanentlyDelete(doc.id);
            }
          },
        ),
      ],
    ),
  );
}

Future<void> renameLibraryDoc(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument doc,
) async {
  final controller = TextEditingController(text: doc.name);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename document'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'e.g. Invoice March 2026',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name != null && name.isNotEmpty) {
    await ref.read(documentsProvider.notifier).rename(doc.id, name);
  }
}

Future<void> shareLibraryDoc(BuildContext context, ScannedDocument doc) async {
  final paths = <String>[];
  if (doc.pdfPath != null && await File(doc.pdfPath!).exists()) {
    paths.add(doc.pdfPath!);
  } else {
    paths.addAll(doc.exportImagePaths.where((p) => File(p).existsSync()));
    if (paths.isEmpty) {
      for (final page in doc.pages) {
        if (File(page.displayPath).existsSync()) {
          paths.add(page.displayPath);
        }
      }
    }
  }
  if (paths.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to share yet. Save the document first.'),
        ),
      );
    }
    return;
  }
  await SharePlus.instance.share(
    ShareParams(files: paths.map((p) => XFile(p)).toList(), subject: doc.name),
  );
}

Future<void> moveLibraryDocToTrash(
  BuildContext context,
  WidgetRef ref,
  ScannedDocument doc,
) async {
  final ok = await showConfirmSheet(
    context: context,
    title: 'Move to Trash?',
    message:
        '“${doc.name}” moves to Deleted. You can restore it later, or it will be removed automatically after the trash period.',
    confirmLabel: 'Move to Trash',
  );
  if (ok) {
    await ref.read(documentsProvider.notifier).delete(doc.id);
  }
}
