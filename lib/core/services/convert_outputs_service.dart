import 'dart:convert';
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
    this.isFavorite = false,
    this.tags = const [],
  });

  final String path;
  final String name;
  final DateTime modifiedAt;
  final int bytes;
  final String? kindLabel;
  final bool isFavorite;
  final List<String> tags;

  String get meta {
    final parts = <String>[?kindLabel, 'Convert', _friendlySize(bytes)];
    return parts.join(' · ');
  }

  ConvertOutput copyWith({bool? isFavorite, List<String>? tags}) =>
      ConvertOutput(
        path: path,
        name: name,
        modifiedAt: modifiedAt,
        bytes: bytes,
        kindLabel: kindLabel,
        isFavorite: isFavorite ?? this.isFavorite,
        tags: tags ?? this.tags,
      );

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

  static const _metaName = 'library.json';

  static Future<Directory> convertsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'converts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> _metaFile() async =>
      File(p.join((await convertsDir()).path, _metaName));

  static Future<Map<String, Map<String, dynamic>>> _loadMetaMap() async {
    final file = await _metaFile();
    if (!await file.exists()) return {};
    try {
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.value is Map)
            e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveMetaMap(
    Map<String, Map<String, dynamic>> map,
  ) async {
    final file = await _metaFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(map), flush: true);
    await tmp.rename(file.path);
  }

  static String _key(String path) => p.basename(path);

  static ConvertOutput _withMeta(
    ConvertOutput out,
    Map<String, Map<String, dynamic>> meta,
  ) {
    final row = meta[_key(out.path)];
    if (row == null) return out;
    final tags =
        (row['tags'] as List?)
            ?.map((e) => e.toString())
            .where((t) => t.isNotEmpty)
            .toList() ??
        const <String>[];
    return out.copyWith(
      isFavorite: row['isFavorite'] as bool? ?? false,
      tags: tags,
    );
  }

  /// Newest first. Skips temp / hidden / sidecar files.
  static Future<List<ConvertOutput>> list() async {
    final dir = await convertsDir();
    if (!await dir.exists()) return const [];
    final meta = await _loadMetaMap();

    final out = <ConvertOutput>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('.') || name.startsWith('incoming_')) continue;
      if (name == 'index.json' || name == _metaName || name.endsWith('.tmp')) {
        continue;
      }
      try {
        final stat = await entity.stat();
        out.add(
          _withMeta(
            ConvertOutput(
              path: entity.path,
              name: name,
              modifiedAt: stat.modified,
              bytes: stat.size,
              kindLabel: _kindFromName(name),
            ),
            meta,
          ),
        );
      } catch (_) {}
    }
    out.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return out;
  }

  static Future<void> setFavorite(String path, bool value) async {
    final map = await _loadMetaMap();
    final key = _key(path);
    final row = Map<String, dynamic>.from(map[key] ?? {});
    row['isFavorite'] = value;
    map[key] = row;
    await _saveMetaMap(map);
  }

  static Future<void> setTags(String path, List<String> tags) async {
    final map = await _loadMetaMap();
    final key = _key(path);
    final row = Map<String, dynamic>.from(map[key] ?? {});
    final cleaned =
        tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    row['tags'] = cleaned;
    map[key] = row;
    await _saveMetaMap(map);
  }

  static Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
    final map = await _loadMetaMap();
    if (map.remove(_key(path)) != null) await _saveMetaMap(map);
  }

  /// `Contract_TXT_2026-08-16_1445.txt` → `TXT`
  static String? _kindFromName(String name) {
    final match = RegExp(
      r'_(TXT|PDF|JPG|PNG|WEBP|GIF|CSV|DOCX|XLSX|CROP|RESIZE|COMPRESS|MERGE|SPLIT|EXTRACT|ROTATE|REORDER|PAGES)_\d{4}-\d{2}-\d{2}_',
    ).firstMatch(name);
    return match?.group(1);
  }
}

final convertOutputsProvider =
    StateNotifierProvider<
      ConvertOutputsController,
      AsyncValue<List<ConvertOutput>>
    >((ref) => ConvertOutputsController()..refresh());

class ConvertOutputsController
    extends StateNotifier<AsyncValue<List<ConvertOutput>>> {
  ConvertOutputsController() : super(const AsyncValue.loading());

  ConvertOutput? _byPath(String path) {
    final list = state.valueOrNull;
    if (list == null) return null;
    for (final c in list) {
      if (c.path == path) return c;
    }
    return null;
  }

  /// Reloads from disk. Keeps the last list on screen (no loading flash).
  Future<void> refresh() async {
    final previous = state.valueOrNull;
    try {
      final list = await ConvertOutputsService.list();
      if (!mounted) return;
      state = AsyncValue.data(list);
    } catch (e, st) {
      if (!mounted) return;
      if (previous != null) {
        state = AsyncValue.data(previous);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> setFavorite(String path, bool value) async {
    await ConvertOutputsService.setFavorite(path, value);
    await refresh();
  }

  Future<void> setTags(String path, List<String> tags) async {
    await ConvertOutputsService.setTags(path, tags);
    await refresh();
  }

  Future<void> addTag(String path, String tagId) async {
    final cur = _byPath(path);
    final next = [...?cur?.tags];
    final t = tagId.trim();
    if (t.isEmpty || next.contains(t)) return;
    next.add(t);
    await setTags(path, next);
  }

  Future<void> toggleTag(String path, String tagId) async {
    final cur = _byPath(path);
    final next = [...?cur?.tags];
    if (next.contains(tagId)) {
      next.remove(tagId);
    } else {
      next.add(tagId);
    }
    await setTags(path, next);
  }
}
