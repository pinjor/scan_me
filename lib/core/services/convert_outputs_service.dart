import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One file under app `converts/` (converter / image-tool output).
class ConvertOutput {
  const ConvertOutput({
    required this.path,
    required this.name,
    required this.modifiedAt,
    required this.bytes,
    this.kindLabel,
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int bytes;
  final String? kindLabel;

  String get meta {
    final parts = <String>[
      ?kindLabel,
      'Convert',
      _friendlySize(bytes),
    ];
    return parts.join(' · ');
  }

  static String _friendlySize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

abstract final class ConvertOutputsService {
  ConvertOutputsService._();

  static Future<Directory> convertsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'converts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Newest first. Skips temp / hidden files.
  static Future<List<ConvertOutput>> list({int limit = 40}) async {
    final dir = await convertsDir();
    if (!await dir.exists()) return const [];

    final out = <ConvertOutput>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.') || name.startsWith('incoming_')) continue;
      if (name == 'index.json') continue;
      try {
        final stat = await entity.stat();
        out.add(
          ConvertOutput(
            path: entity.path,
            name: name,
            modifiedAt: stat.modified,
            bytes: stat.size,
            kindLabel: _kindFromName(name),
          ),
        );
      } catch (_) {
        // Skip unreadable.
      }
    }
    out.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    if (out.length <= limit) return out;
    return out.sublist(0, limit);
  }

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// `Contract_TXT_2026-08-16_1445.txt` → `TXT`
  static String? _kindFromName(String name) {
    final match = RegExp(
      r'_(TXT|PDF|JPG|PNG|WEBP|GIF|CSV|DOCX|XLSX|CROP|RESIZE|COMPRESS)_\d{4}-\d{2}-\d{2}_',
    ).firstMatch(name);
    return match?.group(1);
  }
}

final convertOutputsProvider =
    StateNotifierProvider<ConvertOutputsController, AsyncValue<List<ConvertOutput>>>(
  (ref) => ConvertOutputsController()..refresh(),
);

class ConvertOutputsController
    extends StateNotifier<AsyncValue<List<ConvertOutput>>> {
  ConvertOutputsController() : super(const AsyncValue.loading());

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ConvertOutputsService.list());
  }
}
