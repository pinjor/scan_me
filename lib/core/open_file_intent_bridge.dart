import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../features/converters/convert_catalog.dart';
import '../../features/converters/image_compress_tool_screen.dart';
import '../../features/converters/image_crop_tool_screen.dart';
import '../../features/converters/image_resize_tool_screen.dart';
import '../../features/converters/intent_convert_screen.dart';
import '../../features/file_viewer/file_viewer_screen.dart';
import '../../shared/widgets/app_transitions.dart';

/// Root navigator for intent / open-with routes (no BuildContext yet).
final GlobalKey<NavigatorState> scanMeNavigatorKey = GlobalKey<NavigatorState>();

/// Handles Android / iOS “Open with ScanMe” file intents (view or convert).
abstract final class OpenFileIntentBridge {
  OpenFileIntentBridge._();

  static const _channel = MethodChannel('app.atl.scanme/open_file');
  static String? _pendingPath;
  static String _pendingAction = 'view';
  static bool _listening = false;

  static void ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onOpenFile') {
        await _handlePayload(call.arguments);
      }
      return null;
    });
    unawaited(_consumeInitial());
  }

  static Future<void> _consumeInitial() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getInitialFile');
      await _handlePayload(raw);
    } catch (_) {
      // Channel missing on unsupported platforms.
    }
  }

  static Future<void> _handlePayload(dynamic raw) async {
    if (raw == null) return;
    if (raw is String) {
      if (raw.isNotEmpty) await openPath(raw);
      return;
    }
    if (raw is Map) {
      final path = raw['path']?.toString();
      final action = raw['action']?.toString() ?? 'view';
      if (path != null && path.isNotEmpty) {
        await openPath(path, action: action);
      }
    }
  }

  /// Open [path] in viewer or run convert [action] when navigator is ready.
  static Future<void> openPath(String path, {String action = 'view'}) async {
    final file = File(path);
    if (!await file.exists()) return;

    final nav = scanMeNavigatorKey.currentState;
    if (nav == null) {
      _pendingPath = path;
      _pendingAction = action;
      _flushWhenReady();
      return;
    }

    if (action == 'view') {
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => FileViewerScreen(
            path: path,
            title: p.basename(path),
          ),
        ),
      );
      return;
    }

    final kind = switch (action) {
      'pdfToTxt' => IntentConvertKind.pdfToTxt,
      'pdfToDocx' => IntentConvertKind.pdfToDocx,
      'txtToPdf' => IntentConvertKind.txtToPdf,
      'pptxToPdf' => IntentConvertKind.pptxToPdf,
      'docxToPdf' => IntentConvertKind.docxToPdf,
      'xlsxToCsv' => IntentConvertKind.xlsxToCsv,
      'xlsxToPdf' => IntentConvertKind.xlsxToPdf,
      'pngToJpg' || 'toJpg' => IntentConvertKind.toJpg,
      'jpgToPng' || 'toPng' => IntentConvertKind.toPng,
      'toWebp' => IntentConvertKind.toWebp,
      'toGif' => IntentConvertKind.toGif,
      'heicToJpg' => IntentConvertKind.heicToJpg,
      'crop' || 'resize' || 'compress' => null, // handled below
      _ => null,
    };

    if (action == 'crop' || action == 'resize' || action == 'compress') {
      final toolId = switch (action) {
        'crop' => ConvertToolId.crop,
        'resize' => ConvertToolId.resize,
        _ => ConvertToolId.compress,
      };
      await nav.push(
        AppPageRoute<void>(
          builder: (_) => switch (toolId) {
            ConvertToolId.crop => ImageCropToolScreen(initialPath: path),
            ConvertToolId.resize => ImageResizeToolScreen(initialPath: path),
            _ => ImageCompressToolScreen(initialPath: path),
          },
        ),
      );
      return;
    }

    if (kind == null) {
      await openPath(path, action: 'view');
      return;
    }

    await nav.push(
      AppPageRoute<void>(
        builder: (_) => IntentConvertScreen(path: path, kind: kind),
      ),
    );
  }

  static void _flushWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final path = _pendingPath;
      if (path == null) return;
      if (scanMeNavigatorKey.currentState == null) {
        _flushWhenReady();
        return;
      }
      final action = _pendingAction;
      _pendingPath = null;
      _pendingAction = 'view';
      await openPath(path, action: action);
    });
  }
}
