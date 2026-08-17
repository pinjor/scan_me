import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';
import 'image_tools_service.dart';

class ImageResizeToolScreen extends StatefulWidget {
  const ImageResizeToolScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<ImageResizeToolScreen> createState() => _ImageResizeToolScreenState();
}

class _ImageResizeToolScreenState extends State<ImageResizeToolScreen> {
  String? _path;
  int? _w;
  int? _h;
  int? _bytes;
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  double _longEdge = 1600;
  var _mode = _ResizeMode.longEdge;
  var _format = 'jpg';
  bool _busy = false;
  ConvertResult? _result;
  String? _error;

  ConvertToolMeta get _meta => convertToolMeta(ConvertToolId.resize)!;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPath(path));
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPath(String path) async {
    final probe = await ImageToolsService.probe(path);
    if (!mounted) return;
    setState(() {
      _path = path;
      _w = probe.width;
      _h = probe.height;
      _bytes = probe.bytes;
      _widthCtrl.text = '${probe.width}';
      _heightCtrl.text = '${probe.height}';
      _longEdge = probe.width > probe.height
          ? probe.width.toDouble().clamp(64, 8000)
          : probe.height.toDouble().clamp(64, 8000);
      _result = null;
      _error = null;
    });
  }

  Future<void> _pick() async {
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
      dialogTitle: 'Select image to resize',
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
      final result = switch (_mode) {
        _ResizeMode.longEdge => await ImageToolsService.resizePixels(
            imagePath: _path!,
            maxLongEdge: _longEdge.round(),
            format: _format,
          ),
        _ResizeMode.exact => await ImageToolsService.resizePixels(
            imagePath: _path!,
            width: int.tryParse(_widthCtrl.text.trim()) ?? _w,
            height: int.tryParse(_heightCtrl.text.trim()) ?? _h,
            format: _format,
          ),
      };
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
                    '$_w × $_h · ${ImageToolsService.friendlySize(_bytes ?? 0)}',
                    style: text.labelLarge,
                  ),
                ],
              ],
            ),
          ),
          if (_path != null) ...[
            const SizedBox(height: 16),
            SegmentedButton<_ResizeMode>(
              segments: const [
                ButtonSegment(
                  value: _ResizeMode.longEdge,
                  label: Text('Long edge'),
                  icon: Icon(Icons.straighten),
                ),
                ButtonSegment(
                  value: _ResizeMode.exact,
                  label: Text('Exact'),
                  icon: Icon(Icons.aspect_ratio),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 16),
            if (_mode == _ResizeMode.longEdge) ...[
              Text('Max long edge: ${_longEdge.round()} px', style: text.titleSmall),
              Slider(
                value: _longEdge,
                min: 256,
                max: 4096,
                divisions: 30,
                label: '${_longEdge.round()}',
                onChanged: (v) => setState(() => _longEdge = v),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _widthCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Width',
                        suffixText: 'px',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Height',
                        suffixText: 'px',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text('Output format', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ['jpg', 'png', 'webp'])
                  ChoiceChip(
                    label: Text(f.toUpperCase()),
                    selected: _format == f,
                    onSelected: (_) => setState(() => _format = f),
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
                  : const Icon(Icons.photo_size_select_large),
              label: Text(_busy ? 'Resizing…' : 'Resize'),
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

enum _ResizeMode { longEdge, exact }
