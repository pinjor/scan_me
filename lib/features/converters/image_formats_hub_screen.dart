import 'dart:io';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../core/services/access_permission.dart';
import '../../core/services/image_codec_bridge.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';
import 'image_tools_service.dart';

/// Images tool: one screen — preview + Convert / Crop / Resize / Compress tabs.
class ImageFormatsHubScreen extends StatefulWidget {
  const ImageFormatsHubScreen({
    super.key,
    this.initialPath,
    this.initialFormat,
    this.initialAction,
    this.embedded = false,
  });

  final String? initialPath;
  final String? initialFormat;
  final String? initialAction;

  /// Convert tab / nav slot — no back chevron, pad for the shell bar.
  final bool embedded;

  @override
  State<ImageFormatsHubScreen> createState() => _ImageFormatsHubScreenState();
}

enum _ToolTab { convert, crop, resize, compress }

enum _OutFormat { jpg, png, webp, gif }

enum _QualityPreset { high, balanced, small }

enum _ResizeMode { longEdge, exact }

enum _CropAspect { free, original, square, r4_3, r3_4, r16_9, r9_16, exactPx }

class _ImageFormatsHubScreenState extends State<ImageFormatsHubScreen> {
  String? _path;
  Uint8List? _previewBytes;
  Uint8List? _cropBytes;
  int? _w;
  int? _h;
  int? _bytes;

  /// Display format (JPEG / PNG / …) — from ext or file sniff.
  String _sourceFormat = 'Image';

  late _ToolTab _tab;
  late _OutFormat _format;
  _QualityPreset _quality = _QualityPreset.balanced;

  final _cropController = CropController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _cropWCtrl = TextEditingController();
  final _cropHCtrl = TextEditingController();
  _CropAspect _cropAspect = _CropAspect.free;
  double _longEdge = 1600;
  _ResizeMode _resizeMode = _ResizeMode.longEdge;
  double _targetKb = 400;

  bool _busy = false;
  ConvertResult? _result;
  String? _error;

  /// Ops included in the single Apply pipeline.
  bool _useCrop = false;
  bool _useResize = false;
  bool _useConvert = false;
  bool _useCompress = false;

  /// `crop_your_image` auto-zooms to cover when interactive; block until ready.
  bool _cropScaleUnlocked = false;

  ConvertToolMeta get _meta => convertToolMeta(ConvertToolId.imageFormats)!;

  @override
  void initState() {
    super.initState();
    _tab = _parseTab(widget.initialAction) ?? _ToolTab.convert;
    _format = _parseFormat(widget.initialFormat) ?? _OutFormat.jpg;
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPath(path));
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _cropWCtrl.dispose();
    _cropHCtrl.dispose();
    super.dispose();
  }

  static _OutFormat? _parseFormat(String? raw) {
    return switch (raw?.toLowerCase()) {
      'jpg' || 'jpeg' => _OutFormat.jpg,
      'png' => _OutFormat.png,
      'webp' => _OutFormat.webp,
      'gif' => _OutFormat.gif,
      _ => null,
    };
  }

  static _ToolTab? _parseTab(String? raw) {
    return switch (raw?.toLowerCase()) {
      'crop' => _ToolTab.crop,
      'resize' => _ToolTab.resize,
      'compress' => _ToolTab.compress,
      'convert' => _ToolTab.convert,
      _ => null,
    };
  }

  static String _formatLabelFor(String path, {Uint8List? bytes}) {
    final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
    final fromExt = switch (ext) {
      'jpg' || 'jpeg' => 'JPEG',
      'png' => 'PNG',
      'webp' => 'WebP',
      'gif' => 'GIF',
      'heic' => 'HEIC',
      'heif' => 'HEIF',
      'bmp' => 'BMP',
      _ => null,
    };
    if (fromExt != null) return fromExt;

    final raw = bytes;
    if (raw != null && raw.length >= 12) {
      // JPEG
      if (raw[0] == 0xFF && raw[1] == 0xD8 && raw[2] == 0xFF) return 'JPEG';
      // PNG
      if (raw[0] == 0x89 &&
          raw[1] == 0x50 &&
          raw[2] == 0x4E &&
          raw[3] == 0x47) {
        return 'PNG';
      }
      // GIF
      if (raw[0] == 0x47 && raw[1] == 0x49 && raw[2] == 0x46) return 'GIF';
      // WebP: RIFF....WEBP
      if (raw[0] == 0x52 &&
          raw[1] == 0x49 &&
          raw[2] == 0x46 &&
          raw[3] == 0x46 &&
          raw[8] == 0x57 &&
          raw[9] == 0x45 &&
          raw[10] == 0x42 &&
          raw[11] == 0x50) {
        return 'WebP';
      }
      // HEIC/HEIF: ftyp....heic/heif/mif1
      if (raw.length >= 12 &&
          raw[4] == 0x66 &&
          raw[5] == 0x74 &&
          raw[6] == 0x79 &&
          raw[7] == 0x70) {
        final brand = String.fromCharCodes(raw.sublist(8, 12));
        if (brand.contains('heic') ||
            brand.contains('heif') ||
            brand.contains('mif1') ||
            brand.contains('msf1')) {
          return 'HEIC';
        }
      }
    }

    if (ext.isNotEmpty) return ext.toUpperCase();
    return 'Image';
  }

  Future<void> _loadPath(String path) async {
    final probe = await ImageToolsService.probe(path);
    Uint8List? preview;
    Uint8List? cropBytes;
    Uint8List? head;
    try {
      final file = File(path);
      if (await file.exists()) {
        final len = await file.length();
        final raf = await file.open();
        try {
          head = await raf.read(len < 64 ? len : 64);
        } finally {
          await raf.close();
        }
      }
    } catch (_) {}

    final formatLabel = _formatLabelFor(path, bytes: head);
    final ext = p.extension(path).toLowerCase();
    if (ext == '.heic' || ext == '.heif' || formatLabel == 'HEIC') {
      preview = await ImageCodecBridge.heicToJpeg(path);
    }
    try {
      final decoded = await DocumentConverterService.decodeAnyImage(path);
      cropBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 95));
      preview ??= cropBytes;
    } catch (_) {
      // Preview may still work via Image.file for common formats.
    }
    if (!mounted) return;
    setState(() {
      _path = path;
      _previewBytes = preview;
      _cropBytes = cropBytes;
      _w = probe.width;
      _h = probe.height;
      _bytes = probe.bytes;
      _sourceFormat = formatLabel;
      _widthCtrl.text = '${probe.width}';
      _heightCtrl.text = '${probe.height}';
      _cropWCtrl.text = '${probe.width}';
      _cropHCtrl.text = '${probe.height}';
      _cropAspect = _CropAspect.free;
      _longEdge = probe.width > probe.height
          ? probe.width.toDouble().clamp(64, 8000)
          : probe.height.toDouble().clamp(64, 8000);
      _targetKb = (probe.bytes / 1024).clamp(80, 5000).toDouble();
      if (_targetKb > 800) _targetKb = 400;
      _format = _formatFromSourceLabel(formatLabel);
      _useCrop = false;
      _useResize = false;
      _useConvert = false;
      _useCompress = false;
      _cropScaleUnlocked = false;
      _result = null;
      _error = null;
    });
  }

  static _OutFormat _formatFromSourceLabel(String label) {
    return switch (label) {
      'PNG' => _OutFormat.png,
      'WebP' => _OutFormat.webp,
      'GIF' => _OutFormat.gif,
      _ => _OutFormat.jpg,
    };
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
      dialogTitle: 'Select image',
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

  void _selectTab(_ToolTab tab) {
    if (_path == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Choose an image first.')));
      return;
    }
    setState(() {
      _tab = tab;
      if (tab == _ToolTab.crop) _useCrop = true;
      _result = null;
      _error = null;
    });
  }

  int get _qualityValue => switch (_quality) {
    _QualityPreset.high => 95,
    _QualityPreset.balanced => 85,
    _QualityPreset.small => 70,
  };

  bool get _qualityApplies =>
      _format == _OutFormat.jpg || _format == _OutFormat.webp;

  /// Resize keeps source type unless Convert is also included.
  String get _preserveFormat {
    return switch (_sourceFormat) {
      'PNG' => 'png',
      'WebP' => 'webp',
      'GIF' => 'gif',
      _ => 'jpg', // JPEG / HEIC / unknown → JPEG
    };
  }

  List<String> get _plannedOps {
    final ops = <String>[];
    if (_useCrop) ops.add('Crop');
    if (_useResize) ops.add('Resize');
    if (_useConvert) {
      ops.add(switch (_format) {
        _OutFormat.jpg => 'JPEG',
        _OutFormat.png => 'PNG',
        _OutFormat.webp => 'WebP',
        _OutFormat.gif => 'GIF',
      });
    }
    if (_useCompress) ops.add('Compress');
    return ops;
  }

  void _applyAll() {
    if (_path == null || _busy) return;
    if (_plannedOps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set at least one edit (Convert, Crop, Resize, or Compress), then Apply.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    if (_useCrop) {
      if (_cropBytes == null) {
        setState(() {
          _busy = false;
          _error = 'Could not load this image for cropping.';
        });
        return;
      }
      _cropController.crop();
      return;
    }
    _runPipeline();
  }

  Future<void> _onCropped(CropResult result) async {
    switch (result) {
      case CropSuccess(:final croppedImage):
        await _runPipeline(croppedBytes: croppedImage);
      case CropFailure(:final cause):
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = '$cause';
        });
    }
  }

  /// Order: crop (bytes) → resize → convert format → compress.
  Future<void> _runPipeline({Uint8List? croppedBytes}) async {
    if (_path == null) return;
    try {
      ConvertResult? step;
      var current = _path!;

      if (croppedBytes != null) {
        step = await ImageToolsService.saveCroppedBytes(
          sourcePath: _path!,
          croppedBytes: croppedBytes,
          format: 'jpg',
          quality: 95,
        );
        if (_cropAspect == _CropAspect.exactPx) {
          final cw = int.tryParse(_cropWCtrl.text.trim());
          final ch = int.tryParse(_cropHCtrl.text.trim());
          if (cw != null && ch != null && cw > 0 && ch > 0) {
            step = await ImageToolsService.resizePixels(
              imagePath: step.outputPath,
              width: cw,
              height: ch,
              format: 'jpg',
              quality: 95,
            );
          }
        }
        current = step.outputPath;
      }

      if (_useResize) {
        step = switch (_resizeMode) {
          _ResizeMode.longEdge => await ImageToolsService.resizePixels(
            imagePath: current,
            maxLongEdge: _longEdge.round(),
            format: 'jpg',
            quality: 95,
          ),
          _ResizeMode.exact => await ImageToolsService.resizePixels(
            imagePath: current,
            width: int.tryParse(_widthCtrl.text.trim()) ?? _w,
            height: int.tryParse(_heightCtrl.text.trim()) ?? _h,
            format: 'jpg',
            quality: 95,
          ),
        };
        current = step.outputPath;
      }

      if (_useCompress) {
        if (_useConvert && _format != _OutFormat.jpg) {
          step = await ImageToolsService.convertImage(
            imagePath: current,
            format: _format.name,
            quality: _qualityValue,
          );
          current = step.outputPath;
        }
        step = await ImageToolsService.compressToSize(
          imagePath: current,
          targetBytes: (_targetKb * 1024).round(),
        );
      } else {
        final fmt = _useConvert ? _format.name : _preserveFormat;
        final quality = _useConvert ? _qualityValue : 92;
        // Always produce a final file when convert/crop/resize ran.
        if (_useConvert || croppedBytes != null || _useResize || step == null) {
          step = await ImageToolsService.convertImage(
            imagePath: current,
            format: fmt,
            quality: quality,
          );
        }
      }

      if (!mounted) return;
      final done = step;
      final label = _plannedOps.isEmpty ? done.label : _plannedOps.join(' · ');
      setState(() {
        _busy = false;
        _result = ConvertResult(
          outputPath: done.outputPath,
          label: label,
          mimeType: done.mimeType,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  double? get _cropAspectRatio {
    switch (_cropAspect) {
      case _CropAspect.free:
        return null;
      case _CropAspect.original:
        if (_w == null || _h == null || _h == 0) return null;
        return _w! / _h!;
      case _CropAspect.square:
        return 1;
      case _CropAspect.r4_3:
        return 4 / 3;
      case _CropAspect.r3_4:
        return 3 / 4;
      case _CropAspect.r16_9:
        return 16 / 9;
      case _CropAspect.r9_16:
        return 9 / 16;
      case _CropAspect.exactPx:
        final w = int.tryParse(_cropWCtrl.text.trim());
        final h = int.tryParse(_cropHCtrl.text.trim());
        if (w == null || h == null || w <= 0 || h <= 0) return null;
        return w / h;
    }
  }

  void _setCropAspect(_CropAspect aspect) {
    setState(() {
      _cropAspect = aspect;
      _useCrop = true;
      // Remount Crop (new key) — re-block auto cover zoom.
      _cropScaleUnlocked = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _cropController.aspectRatio = _cropAspectRatio;
      } catch (_) {
        // Crop editor not ready yet — aspectRatio on Crop widget covers init.
      }
    });
  }

  void _syncExactCropAspect() {
    if (_cropAspect != _CropAspect.exactPx) return;
    try {
      _cropController.aspectRatio = _cropAspectRatio;
    } catch (_) {}
    setState(() => _useCrop = true);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _path != null;
    final workspace = _buildToolWorkspace(context);

    if (widget.embedded) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Edit photo', style: text.headlineSmall),
                  ),
                  if (hasImage)
                    TextButton(
                      onPressed: _busy ? null : _pick,
                      child: const Text('Change'),
                    ),
                ],
              ),
            ),
            Expanded(child: workspace),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(_meta.title),
        actions: [
          if (hasImage)
            TextButton(
              onPressed: _busy ? null : _pick,
              child: const Text('Change'),
            ),
        ],
      ),
      body: workspace,
    );
  }

  /// Same chrome empty or loaded: controls top · image area · CTA bottom.
  Widget _buildToolWorkspace(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final hasImage = _path != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.42,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasImage) ...[
                  ConvertToolHero(tool: _meta),
                  const SizedBox(height: 12),
                ] else
                  Text(
                    '$_sourceFormat · $_w × $_h · ${ImageToolsService.friendlySize(_bytes ?? 0)}',
                    style: text.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                if (hasImage) const SizedBox(height: 10),
                _ToolRail(
                  selected: _tab,
                  enabled: !_busy,
                  onSelect: _selectTab,
                ),
                const SizedBox(height: 8),
                Text(
                  hasImage
                      ? _tabBlurb
                      : 'Choose a photo first, then set edits and Apply.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 10),
                  switch (_tab) {
                    _ToolTab.convert => _buildConvertOptions(context),
                    _ToolTab.crop => _buildCropAspectChips(context),
                    _ToolTab.resize => _buildResizeOptions(context),
                    _ToolTab.compress => _buildCompressOptions(context),
                  },
                  if (_tab == _ToolTab.crop &&
                      _cropAspect == _CropAspect.exactPx) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cropWCtrl,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Width',
                              suffixText: 'px',
                              isDense: true,
                            ),
                            onChanged: (_) => _syncExactCropAspect(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _cropHCtrl,
                            enabled: !_busy,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Height',
                              suffixText: 'px',
                              isDense: true,
                            ),
                            onChanged: (_) => _syncExactCropAspect(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildImageSlot(context, hasImage: hasImage),
          ),
        ),
        SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              widget.embedded ? 100 : 16,
            ),
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
                if (hasImage && _result != null && !_busy) ...[
                  ConvertResultPanel(result: _result!),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _result = null;
                            _error = null;
                          }),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit again'),
                    style: convertOutlineButtonStyle(),
                  ),
                ] else if (hasImage) ...[
                  if (_plannedOps.isNotEmpty) ...[
                    _buildPlannedOpsChips(context),
                    const SizedBox(height: 10),
                  ],
                  _buildPrimaryCta(context),
                ] else
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choose image'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Source / crop UI, or finished output — never leave crop canvas under Ready.
  Widget _buildImageSlot(BuildContext context, {required bool hasImage}) {
    if (!hasImage) return _buildEmptyPreview(context);

    if (_result != null && !_busy) {
      return _ImagePreview(path: _result!.outputPath, expand: true);
    }

    // Keep Crop mounted (Offstage) so Apply can bake crop from any tab.
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cropBytes != null)
          Offstage(
            offstage: _tab != _ToolTab.crop,
            child: _buildCropViewport(context),
          ),
        if (_tab != _ToolTab.crop)
          _ImagePreview(
            path: _path!,
            previewBytes: _previewBytes,
            expand: true,
          ),
        if (_busy)
          const ColoredBox(
            color: Color(0x66000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildEmptyPreview(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 48,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                'No photo yet',
                style: text.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryCta(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : _applyAll,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check),
      label: Text(_busy ? 'Applying…' : 'Apply'),
      style: convertPrimaryButtonStyle(),
    );
  }

  /// Staging chips above the one Apply — tap × to drop an edit.
  Widget _buildPlannedOpsChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Then Apply once',
          style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_useCrop)
              InputChip(
                label: const Text('Crop'),
                onDeleted: _busy
                    ? null
                    : () => setState(() => _useCrop = false),
              ),
            if (_useResize)
              InputChip(
                label: const Text('Resize'),
                onDeleted: _busy
                    ? null
                    : () => setState(() => _useResize = false),
              ),
            if (_useConvert)
              InputChip(
                label: Text(switch (_format) {
                  _OutFormat.jpg => 'JPEG',
                  _OutFormat.png => 'PNG',
                  _OutFormat.webp => 'WebP',
                  _OutFormat.gif => 'GIF',
                }),
                onDeleted: _busy
                    ? null
                    : () => setState(() => _useConvert = false),
              ),
            if (_useCompress)
              InputChip(
                label: const Text('Compress'),
                onDeleted: _busy
                    ? null
                    : () => setState(() => _useCompress = false),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCropAspectChips(BuildContext context) {
    const aspects = <({_CropAspect value, String label})>[
      (value: _CropAspect.free, label: 'Free'),
      (value: _CropAspect.original, label: 'Original'),
      (value: _CropAspect.square, label: '1:1'),
      (value: _CropAspect.r4_3, label: '4:3'),
      (value: _CropAspect.r3_4, label: '3:4'),
      (value: _CropAspect.r16_9, label: '16:9'),
      (value: _CropAspect.r9_16, label: '9:16'),
      (value: _CropAspect.exactPx, label: 'Exact px'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in aspects)
          ChoiceChip(
            label: Text(a.label),
            selected: _cropAspect == a.value,
            onSelected: _busy ? null : (_) => _setCropAspect(a.value),
          ),
      ],
    );
  }

  Widget _buildCropViewport(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_cropBytes == null) {
      return Center(
        child: Text(
          'Could not load this image for cropping.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }

    // Locked ratios: fixed frame + pinch/pan photo (reliable).
    // Free: corners resize frame; pinch still zooms photo.
    final fixFrame = _cropAspect != _CropAspect.free;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Crop(
            key: ValueKey('crop-$_cropAspect-$fixFrame'),
            image: _cropBytes!,
            controller: _cropController,
            aspectRatio: _cropAspectRatio,
            onCropped: _onCropped,
            interactive: true,
            fixCropRect: fixFrame,
            // Package applies scaleToCover on ready; reject until unlocked.
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
            cornerDotBuilder: (size, edge) =>
                DotControl(color: scheme.primary),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  String get _tabBlurb => switch (_tab) {
    _ToolTab.convert =>
      'Pick output type & quality. Apply runs everything together.',
    _ToolTab.crop => 'Frame the photo. Apply runs crop with your other edits.',
    _ToolTab.resize =>
      'Set pixel size. Apply runs resize with your other edits.',
    _ToolTab.compress =>
      'Set target KB. Apply compresses last (JPEG) with your other edits.',
  };

  Widget _buildConvertOptions(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          _DropdownRow<_OutFormat>(
            label: 'Convert to',
            value: _format,
            enabled: !_busy,
            items: const [
              (value: _OutFormat.jpg, label: 'JPEG (.jpg)'),
              (value: _OutFormat.png, label: 'PNG (.png)'),
              (value: _OutFormat.webp, label: 'WebP (.webp)'),
              (value: _OutFormat.gif, label: 'GIF (.gif)'),
            ],
            onChanged: (v) => setState(() {
              _format = v;
              _useConvert = true;
            }),
          ),
          if (_qualityApplies) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            _DropdownRow<_QualityPreset>(
              label: 'Quality',
              value: _quality,
              enabled: !_busy,
              items: const [
                (value: _QualityPreset.high, label: 'High — best detail'),
                (
                  value: _QualityPreset.balanced,
                  label: 'Balanced — recommended',
                ),
                (value: _QualityPreset.small, label: 'Small — smaller file'),
              ],
              onChanged: (v) => setState(() {
                _quality = v;
                _useConvert = true;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResizeOptions(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          selected: {_resizeMode},
          onSelectionChanged: _busy
              ? null
              : (s) => setState(() {
                  _resizeMode = s.first;
                  _useResize = true;
                }),
        ),
        const SizedBox(height: 12),
        if (_resizeMode == _ResizeMode.longEdge) ...[
          Text(
            'Max long edge: ${_longEdge.round()} px',
            style: text.titleSmall,
          ),
          Slider(
            value: _longEdge,
            min: 256,
            max: 4096,
            divisions: 30,
            label: '${_longEdge.round()}',
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _longEdge = v;
                    _useResize = true;
                  }),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _widthCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Width',
                    suffixText: 'px',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _useResize = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Height',
                    suffixText: 'px',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() => _useResize = true),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompressOptions(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Target size · ≈ ${_targetKb.round()} KB', style: text.titleSmall),
        Slider(
          value: _targetKb,
          min: 50,
          max: 2000,
          divisions: 39,
          label: '${_targetKb.round()} KB',
          onChanged: _busy
              ? null
              : (v) => setState(() {
                  _targetKb = v;
                  _useCompress = true;
                }),
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final kb in [150, 300, 500, 800, 1200])
              ActionChip(
                label: Text('$kb KB'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _targetKb = kb.toDouble();
                        _useCompress = true;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Compress finishes as JPEG.',
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ToolRail extends StatelessWidget {
  const _ToolRail({
    required this.selected,
    required this.onSelect,
    this.enabled = true,
  });

  final _ToolTab selected;
  final ValueChanged<_ToolTab> onSelect;
  final bool enabled;

  static const _items = <({_ToolTab tab, IconData icon, String label})>[
    (tab: _ToolTab.convert, icon: Icons.transform, label: 'Convert'),
    (tab: _ToolTab.crop, icon: Icons.crop, label: 'Crop'),
    (
      tab: _ToolTab.resize,
      icon: Icons.photo_size_select_large,
      label: 'Resize',
    ),
    (tab: _ToolTab.compress, icon: Icons.compress, label: 'Compress'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevated: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: _ToolRailItem(
                icon: item.icon,
                label: item.label,
                selected: selected == item.tab,
                enabled: enabled,
                onTap: () => onSelect(item.tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolRailItem extends StatelessWidget {
  const _ToolRailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.primary : scheme.onSurfaceVariant;
    final bg = selected
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: selected
                      ? Border.all(
                          color: scheme.primary.withValues(alpha: 0.45),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Icon(icon, color: fg, size: 24),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.path,
    this.previewBytes,
    this.expand = false,
  });

  final String path;
  final Uint8List? previewBytes;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fit = expand ? BoxFit.contain : BoxFit.cover;
    final image = previewBytes != null
        ? Image.memory(previewBytes!, fit: fit, gaplessPlayback: true)
        : Image.file(
            File(path),
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: scheme.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          );

    final framed = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: expand ? Center(child: image) : image,
      ),
    );

    if (expand) return framed;

    return AspectRatio(aspectRatio: 16 / 10, child: framed);
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<({T value, String label})> items;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                itemHeight: 48,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                icon: Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
                style: text.bodyLarge?.copyWith(color: scheme.onSurface),
                items: [
                  for (final item in items)
                    DropdownMenuItem<T>(
                      value: item.value,
                      child: Text(item.label),
                    ),
                ],
                onChanged: enabled
                    ? (v) {
                        if (v != null) onChanged(v);
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
