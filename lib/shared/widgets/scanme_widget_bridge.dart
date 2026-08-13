// Future-ready home-widget entry points.
//
// Do not wire Android Glance / iOS WidgetKit until product ships widgets.
// Deep links / intents should call [handleIncomingAction].
import '../models/library_models.dart';

export '../models/library_models.dart' show ScanMeWidgetBridge;

typedef WidgetActionHandler = Future<void> Function(Uri action);

/// Routes widget / shortcut actions into the Flutter app.
class ScanMeWidgetRouter {
  ScanMeWidgetRouter._();

  static WidgetActionHandler? onNewScan;

  /// Returns true if [uri] or Android action string was handled.
  static Future<bool> handleIncomingAction(String raw) async {
    final normalized = raw.trim();
    if (normalized == ScanMeWidgetBridge.androidScanNowAction ||
        normalized == ScanMeWidgetBridge.iosNewScanUrl ||
        normalized == ScanMeWidgetBridge.newScanDeepLink.toString()) {
      final handler = onNewScan;
      if (handler == null) return false;
      await handler(ScanMeWidgetBridge.newScanDeepLink);
      return true;
    }
    final uri = Uri.tryParse(normalized);
    if (uri != null &&
        uri.scheme == 'scanme' &&
        (uri.host == 'new-scan' || uri.path.contains('new-scan'))) {
      final handler = onNewScan;
      if (handler == null) return false;
      await handler(uri);
      return true;
    }
    return false;
  }
}
