import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../core/services/access_permission.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';
import 'image_tools_service.dart';

class ImageCropToolScreen extends StatefulWidget {
  const ImageCropToolScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<ImageCropToolScreen> createState() => _ImageCropToolScreenState();
}

class _ImageCropToolScreenState extends State<ImageCropToolScreen> {
  final _controller = CropController();
  Uint8List? _bytes;
  String? _sourcePath;
  ConvertResult? _result;
  bool _busy = false;
  String? _error;
  bool _cropScaleUnlocked = false;

  ConvertToolMeta get _meta => convertToolMeta(ConvertToolId.crop)!;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPath(path));
    }
  }

  Future<void> _loadPath(String path) async {
    final decoded = await DocumentConverterService.decodeAnyImage(path);
    final jpg = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
    if (!mounted) return;
    setState(() {
      _sourcePath = path;
      _bytes = jpg;
      _result = null;
      _error = null;
      _cropScaleUnlocked = false;
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
      dialogTitle: 'Select image to crop',
    );
    if (file == null) return;

    var path = file.path;
    if (path == null || path.isEmpty) {
      final bytes = await file.readAsBytes();
      path = await DocumentConverterService.materializePath(
        preferredName: file.name,
        bytes: bytes,
      );
    }
    await _loadPath(path);
  }

  void _crop() {
    if (_bytes == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        try {
          final saved = await ImageToolsService.saveCroppedBytes(
            sourcePath: _sourcePath!,
            croppedBytes: croppedImage,
            format: 'jpg',
          );
          if (!mounted) return;
          setState(() {
            _busy = false;
            _result = saved;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _error = '$e';
          });
        }
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = '$cause';
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
        actions: [
          if (_bytes != null)
            TextButton(
              onPressed: _busy ? null : _crop,
              child: const Text('Apply'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_bytes == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConvertToolHero(tool: _meta),
            ),
          Expanded(
            child: _bytes == null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppEmptyState(
                      title: 'Ready to crop',
                      subtitle: 'Pick a photo, adjust the frame, then Apply.',
                      primaryLabel: 'Choose image',
                      primaryIcon: Icons.crop,
                      onPrimary: _pick,
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Crop(
                        image: _bytes!,
                        controller: _controller,
                        onCropped: _onCropped,
                        interactive: true,
                        willUpdateScale: (_) => _cropScaleUnlocked,
                        onStatusChanged: (status) {
                          if (status == CropStatus.ready) {
                            _cropScaleUnlocked = true;
                          } else if (status == CropStatus.loading) {
                            _cropScaleUnlocked = false;
                          }
                        },
                        baseColor: scheme.surfaceContainerHighest,
                        maskColor: Colors.black.withValues(alpha: 0.55),
                        cornerDotBuilder: (size, edge) => DotControl(
                          color: scheme.primary,
                        ),
                      ),
                      if (_busy)
                        const ColoredBox(
                          color: Color(0x66000000),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: text.bodySmall?.copyWith(color: scheme.error),
                      ),
                    ),
                  if (_result != null) ConvertResultPanel(result: _result!),
                  if (_result == null) ...[
                    if (_bytes != null)
                      FilledButton.icon(
                        onPressed: _busy ? null : _crop,
                        icon: const Icon(Icons.check),
                        label: const Text('Apply crop'),
                        style: convertPrimaryButtonStyle(),
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(
                        _bytes == null ? 'Choose image' : 'Choose another',
                      ),
                      style: convertOutlineButtonStyle(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
