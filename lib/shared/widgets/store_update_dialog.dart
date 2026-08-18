import 'package:flutter/material.dart';

enum StoreUpdateAction { updateNow, remindLater }

/// Soft caution dialog: update available on Play Store — optional.
Future<StoreUpdateAction?> showStoreUpdateDialog(
  BuildContext context, {
  required String currentVersion,
}) {
  return showDialog<StoreUpdateAction>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;

      return AlertDialog(
        icon: Icon(
          Icons.system_update_alt_rounded,
          size: 36,
          color: scheme.primary,
        ),
        title: const Text('Update available'),
        content: Text(
          'A newer ScanMe is on the Play Store.\n\n'
          'You are on v$currentVersion. Updating is optional — '
          'you can do it now or get a reminder later.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(StoreUpdateAction.remindLater),
            child: const Text('Remind later'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(StoreUpdateAction.updateNow),
            child: const Text('Update now'),
          ),
        ],
      );
    },
  );
}
