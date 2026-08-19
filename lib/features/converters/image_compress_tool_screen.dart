import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/access_permission.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';
import 'image_tools_service.dart';

class ImageCompressToolScreen extends StatefulWidget {
  const ImageCompressToolScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<ImageCompressToolScreen> createState() =>
      _ImageCompressToolScreenState();
}

class _ImageCompressToolScreenState extends State<ImageCompressToolScreen> {
  String? _path;
  int? _bytes;
  int? _w;
  int? _h;
  double _targetKb = 400;
  bool _busy = false;
  ConvertResult? _result;
  String? _error;

  ConvertToolMeta get _meta => convertToolMeta(ConvertToolId.compress)!;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPath(path));
    }
  }

  Future<void> _loadPath(String path) async {
    final probe = await ImageToolsService.probe(path);
    if (!mounted) return;
    setState(() {
      _path = path;
      _bytes = probe.bytes;
      _w = probe.width;
      _h = probe.height;
      _targetKb = (probe.bytes / 1024).clamp(80, 5000).toDouble();
      if (_targetKb > 800) _targetKb = 400;
      _result = null;
      _error = null;
    });
  }

  Future<void> _pick() async {
    if (!await AccessPermission.ensureFiles(context)) return;
    if (!mounted) return;
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'heic',
        'heif',
      ],
      dialogTitle: 'Select image to compress',
    );
    if (file == null) return;
    var path = file.path;
    if (path == null || path.isEmpty) {
      path = await DocumentConverterService.materializePath(
        preferredName: file.name,
        bytes: await file.readAsBytes(),
      );
    }
    await _loadPath(path);
  }

  Future<void> _run() async {
    if (_path == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await ImageToolsService.compressToSize(
        imagePath: _path!,
        targetBytes: (_targetKb * 1024).round(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(_meta.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ConvertToolHero(tool: _meta),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(_path == null ? 'Choose image' : 'Choose another'),
                  style: convertOutlineButtonStyle(),
                ),
                if (_path != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Now: $_w × $_h · ${ImageToolsService.friendlySize(_bytes ?? 0)}',
                    style: text.labelLarge,
                  ),
                ],
              ],
            ),
          ),
          if (_path != null) ...[
            const SizedBox(height: 20),
            Text(
              'Target size · ≈ ${_targetKb.round()} KB',
              style: text.titleSmall,
            ),
            Slider(
              value: _targetKb,
              min: 50,
              max: 2000,
              divisions: 39,
              label: '${_targetKb.round()} KB',
              onChanged: (v) => setState(() => _targetKb = v),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final kb in [150, 300, 500, 800, 1200])
                  ActionChip(
                    label: Text('$kb KB'),
                    onPressed: () => setState(() => _targetKb = kb.toDouble()),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _run,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.compress),
              label: Text(_busy ? 'Compressing…' : 'Reduce size'),
              style: convertPrimaryButtonStyle(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: text.bodySmall?.copyWith(color: scheme.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            ConvertResultPanel(result: _result!),
          ],
        ],
      ),
    );
  }
}
