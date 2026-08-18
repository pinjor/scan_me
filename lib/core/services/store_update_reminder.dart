import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/store_update_dialog.dart';

/// Soft Play Store update reminder (not forced).
///
/// Android: uses Play Core update availability when installed from Play.
/// "Update now" opens the Play Store listing. "Remind later" snoozes
/// for [remindLater] (default 3 days).
abstract final class StoreUpdateReminder {
  StoreUpdateReminder._();

  static const packageId = 'app.atl.scanme';
  static const _prefsRemindAfterKey = 'store_update_remind_after_ms';
  static const Duration remindLater = Duration(days: 3);

  static const playHttps =
      'https://play.google.com/store/apps/details?id=$packageId';
  static const playMarket = 'market://details?id=$packageId';

  /// Call once after first frame of [MainShellScreen].
  static Future<void> maybeShow(BuildContext context) async {
    if (kIsWeb || !Platform.isAndroid) return;
    if (!context.mounted) return;

    try {
      if (!await _shouldPrompt()) return;
      final available = await _playUpdateAvailable();
      if (!available || !context.mounted) return;

      final info = await PackageInfo.fromPlatform();
      if (!context.mounted) return;

      final action = await showStoreUpdateDialog(
        context,
        currentVersion: info.version,
      );
      if (action == StoreUpdateAction.updateNow) {
        await openPlayStore();
      } else if (action == StoreUpdateAction.remindLater) {
        await snooze();
      }
    } catch (_) {
      // Sideload / emulator / Play services missing — stay quiet.
    }
  }

  static Future<bool> _shouldPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final until = prefs.getInt(_prefsRemindAfterKey);
    if (until == null) return true;
    return DateTime.now().millisecondsSinceEpoch >= until;
  }

  /// Exposed for tests.
  static Future<void> snooze({
    DateTime? now,
    Duration duration = remindLater,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final when = (now ?? DateTime.now()).add(duration);
    await prefs.setInt(_prefsRemindAfterKey, when.millisecondsSinceEpoch);
  }

  /// Clears snooze so the next check can show again (tests / debug).
  static Future<void> clearSnooze() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsRemindAfterKey);
  }

  static Future<bool> _playUpdateAvailable() async {
    final info = await InAppUpdate.checkForUpdate();
    return info.updateAvailability == UpdateAvailability.updateAvailable;
  }

  static Future<void> openPlayStore() async {
    final market = Uri.parse(playMarket);
    if (await canLaunchUrl(market)) {
      final ok = await launchUrl(market, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
    await launchUrl(
      Uri.parse(playHttps),
      mode: LaunchMode.externalApplication,
    );
  }
}
