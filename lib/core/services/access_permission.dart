import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/app_ui.dart';

/// Store-safe access asks (Guideline 5.1.1): explain in-app, then the OS dialog,
/// only when the user taps Scan / QR / import / pick a file. Never at cold start.
abstract final class AccessPermission {
  AccessPermission._();

  /// Widget tests: skip OS permission + rationale (no camera plugin).
  static var bypassInTests = false;

  static Future<bool> ensureCamera(BuildContext context) => _ensure(
    context,
    permission: Permission.camera,
    title: 'Camera',
    message:
        'ScanMe uses the camera to capture document pages and read QR codes. '
        'Photos stay on this phone and are not uploaded.',
    icon: Icons.photo_camera_outlined,
  );

  static Future<bool> ensurePhotos(BuildContext context) async {
    if (bypassInTests) return true;
    // Android 13+: system photo picker. No READ_MEDIA_IMAGES (Play policy).
    if (Platform.isAndroid) {
      return _explainPickerOnce(
        context,
        prefsKey: _photosExplainedKey,
        title: 'Photos',
        message:
            'ScanMe will open the system photo picker. You choose the images. '
            'The app does not get access to your whole gallery.',
        icon: Icons.photo_library_outlined,
        confirmLabel: 'Choose photos',
      );
    }
    return _ensure(
      context,
      permission: Permission.photos,
      title: 'Photos',
      message:
          'ScanMe uses photos you pick to import pages, edit an image, or read a QR code. '
          'We only see files you select.',
      icon: Icons.photo_library_outlined,
    );
  }

  static const _filesExplainedKey = 'access_files_explained_v1';
  static const _photosExplainedKey = 'access_photos_picker_explained_v1';

  /// iOS/Android file pickers are the grant (no always-on Files access).
  static Future<bool> ensureFiles(BuildContext context) => _explainPickerOnce(
        context,
        prefsKey: _filesExplainedKey,
        title: 'Files',
        message:
            'ScanMe will open the system file picker. You choose the document. '
            'The app does not get access to your whole storage.',
        icon: Icons.folder_open_outlined,
        confirmLabel: 'Choose file',
      );

  static Future<bool> _explainPickerOnce(
    BuildContext context, {
    required String prefsKey,
    required String title,
    required String message,
    required IconData icon,
    required String confirmLabel,
  }) async {
    if (bypassInTests) return true;
    if (!context.mounted) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(prefsKey) ?? false) return true;
    if (!context.mounted) return false;
    final go = await _showRationale(
      context,
      title: title,
      message: message,
      icon: icon,
      confirmLabel: confirmLabel,
    );
    if (go) await prefs.setBool(prefsKey, true);
    return go;
  }

  static Future<bool> _ensure(
    BuildContext context, {
    required Permission permission,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    if (bypassInTests) return true;
    if (!context.mounted) return false;

    PermissionStatus status;
    try {
      status = await permission.status;
    } catch (_) {
      // Tests / missing plugin — let the platform UI proceed.
      return true;
    }

    if (status.isGranted || status.isLimited || status.isRestricted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _openSettingsPrompt(context, title: title, message: message);
      return false;
    }

    if (!context.mounted) return false;
    final go = await _showRationale(
      context,
      title: title,
      message: message,
      icon: icon,
      confirmLabel: 'Continue',
    );
    if (!go || !context.mounted) return false;

    try {
      status = await permission.request();
    } catch (_) {
      return true;
    }

    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied && context.mounted) {
      await _openSettingsPrompt(context, title: title, message: message);
    }
    return false;
  }

  static Future<bool> _showRationale(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
    required String confirmLabel,
  }) async {
    final ok = await showAppBottomSheet<bool>(
      context: context,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Allow $title?', style: text.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'On this device · no account',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(confirmLabel),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        );
      },
    );
    return ok ?? false;
  }

  static Future<void> _openSettingsPrompt(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showConfirmSheet(
      context: context,
      title: '$title is off',
      message: '$message\n\nTurn it on in Settings to use this feature.',
      confirmLabel: 'Open Settings',
      cancelLabel: 'Not now',
      destructive: false,
      icon: Icons.settings_outlined,
    ).then((ok) async {
      if (ok) await openAppSettings();
    });
  }
}
