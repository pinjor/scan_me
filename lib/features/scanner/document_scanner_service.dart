import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

sealed class ScanOutcome {}

class ScanSuccess extends ScanOutcome {
  ScanSuccess(this.imagePaths);
  final List<String> imagePaths;
}

class ScanCancelled extends ScanOutcome {}

class ScanError extends ScanOutcome {
  ScanError(this.message);
  final String message;
}

/// Platform scanner: ML Kit on Android, VisionKit channel on iOS.
class DocumentScannerService {
  static const _iosChannel = MethodChannel('app.atl.scanme/document_scanner');

  Future<ScanOutcome> scan({int pageLimit = 1}) async {
    try {
      if (Platform.isAndroid) {
        return await _scanAndroid(pageLimit: pageLimit);
      }
      if (Platform.isIOS) {
        return await _scanIos();
      }
      return ScanError('Document scanner only available on Android and iOS.');
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('DocumentScannerService.scan: $e\n$st');
      }
      return ScanError('Scanner failed: $e');
    }
  }

  Future<ScanOutcome> _scanAndroid({required int pageLimit}) async {
    DocumentScanner? scanner;
    try {
      scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg},
          mode: ScannerMode.full,
          pageLimit: pageLimit,
          isGalleryImport: true,
        ),
      );
      final result = await scanner.scanDocument();
      final images = result.images ?? const <String>[];
      if (images.isEmpty) {
        return ScanCancelled();
      }
      return ScanSuccess(images);
    } on PlatformException catch (e) {
      if (e.code.toLowerCase().contains('cancel') ||
          (e.message?.toLowerCase().contains('cancel') ?? false)) {
        return ScanCancelled();
      }
      final raw = '${e.code} ${e.message ?? ''}'.toLowerCase();
      if (raw.contains('play') ||
          raw.contains('gms') ||
          raw.contains('unavailable') ||
          raw.contains('service_missing') ||
          e.code == 'UNAVAILABLE') {
        return ScanError(
          'Document scanner needs Google Play services on this device. '
          'Update Play Store / Play services, or try another phone.',
        );
      }
      return ScanError(
        e.message?.isNotEmpty == true
            ? e.message!
            : 'ML Kit scanner failed (${e.code})',
      );
    } finally {
      await scanner?.close();
    }
  }

  Future<ScanOutcome> _scanIos() async {
    try {
      final supported = await _iosChannel.invokeMethod<bool>('isSupported');
      if (supported == false) {
        return ScanError('Document scanner is not supported on this device.');
      }
      final raw = await _iosChannel.invokeMethod<List<dynamic>>('scan');
      final paths =
          raw
              ?.map((e) => e?.toString() ?? '')
              .where((p) => p.isNotEmpty)
              .toList() ??
          [];
      if (paths.isEmpty) {
        return ScanError('No pages returned from scanner.');
      }
      return ScanSuccess(paths);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELLED') return ScanCancelled();
      return ScanError(e.message ?? 'Scanner failed (${e.code})');
    }
  }
}
