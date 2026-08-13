import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import 'document_converter_service.dart';

enum _ConvertKind {
  pdfToTxt,
  pptxToPdf,
  pngToJpg,
  jpgToPng,
}

class ConvertersHubScreen extends StatefulWidget {
  const ConvertersHubScreen({super.key});

  @override
  State<ConvertersHubScreen> createState() => _ConvertersHubScreenState();
}

class _ConvertersHubScreenState extends State<ConvertersHubScreen> {
  bool _busy = false;
  String? _progress;
  ConvertResult? _last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Converters')),
      body: FadeRiseIn(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 360;
                final tiles = [
                  _tile(
                    icon: Icons.description_outlined,
                    title: 'PDF → Text',
                    kind: _ConvertKind.pdfToTxt,
                  ),
                  _tile(
                    icon: Icons.slideshow_outlined,
                    title: 'PowerPoint → PDF',
                    kind: _ConvertKind.pptxToPdf,
                  ),
                  _tile(
                    icon: Icons.image_outlined,
                    title: 'PNG → JPG',
                    kind: _ConvertKind.pngToJpg,
                  ),
                  _tile(
                    icon: Icons.photo_outlined,
                    title: 'JPG → PNG',
                    kind: _ConvertKind.jpgToPng,
                  ),
                ];
                if (!wide) {
                  return Column(
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        tiles[i],
                      ],
                    ],
                  );
                }
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                  ],
                );
              },
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _progress ?? 'Converting…',
                        key: ValueKey(_progress),
                        style: text.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_last != null && !_busy) ...[
              const SizedBox(height: 24),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Ready', style: text.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      _last!.outputPath.split(Platform.pathSeparator).last,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => _share(_last!),
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text('Share ${_last!.label}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required _ConvertKind kind,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      onTap: _busy ? null : () => _run(kind),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(height: 10),
          Text(title, style: text.titleMedium),
        ],
      ),
    );
  }

  Future<void> _run(_ConvertKind kind) async {
    final picked = await _pick(kind);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _progress = 'Preparing file…';
      _last = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted) setState(() => _progress = 'Converting…');
      final result = switch (kind) {
        _ConvertKind.pdfToTxt =>
          await DocumentConverterService.pdfToTxt(picked),
        _ConvertKind.pptxToPdf =>
          await DocumentConverterService.pptxToPdf(picked),
        _ConvertKind.pngToJpg =>
          await DocumentConverterService.imageToJpeg(picked),
        _ConvertKind.jpgToPng =>
          await DocumentConverterService.imageToPng(picked),
      };
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _last = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.label} ready')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Convert failed: $e')),
      );
    }
  }

  Future<String?> _pick(_ConvertKind kind) async {
    final (exts, title) = switch (kind) {
      _ConvertKind.pdfToTxt => (['pdf'], 'Select PDF'),
      _ConvertKind.pptxToPdf => (['pptx'], 'Select PowerPoint'),
      _ConvertKind.pngToJpg => (
          ['png', 'webp', 'bmp', 'gif', 'heic', 'jpg', 'jpeg'],
          'Select image',
        ),
      _ConvertKind.jpgToPng => (['jpg', 'jpeg', 'jpe'], 'Select JPEG'),
    };

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: exts,
      dialogTitle: title,
    );
    if (file == null) return null;
    final path = file.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that file path.')),
        );
      }
      return null;
    }
    return path;
  }

  Future<void> _share(ConvertResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.outputPath)],
        subject: result.label,
      ),
    );
  }
}
