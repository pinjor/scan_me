import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../file_viewer/file_viewer_screen.dart';
import 'document_converter_service.dart';

enum ConvertKind {
  pdfToTxt,
  txtToPdf,
  pptxToPdf,
  pngToJpg,
  jpgToPng,
}

class ConvertersHubScreen extends StatefulWidget {
  const ConvertersHubScreen({
    super.key,
    this.embedded = false,
  });

  /// When true (Tools tab), no AppBar — shell provides chrome.
  final bool embedded;

  @override
  State<ConvertersHubScreen> createState() => _ConvertersHubScreenState();
}

class _ConvertersHubScreenState extends State<ConvertersHubScreen> {
  bool _busy = false;
  String? _progress;
  ConvertResult? _last;

  static const _tiles = <(IconData, String, String, ConvertKind, Color)>[
    (
      Icons.article_outlined,
      'PDF to .txt',
      'Save PDF text as a .txt file',
      ConvertKind.pdfToTxt,
      Color(0xFF1565C0),
    ),
    (
      Icons.picture_as_pdf_outlined,
      '.txt to PDF',
      'Turn a .txt file into a PDF',
      ConvertKind.txtToPdf,
      Color(0xFFC62828),
    ),
    (
      Icons.present_to_all_outlined,
      'PowerPoint to PDF',
      'Convert .pptx slides to PDF',
      ConvertKind.pptxToPdf,
      Color(0xFFEF6C00),
    ),
    (
      Icons.image_outlined,
      'PNG to JPG',
      'Save a PNG as a JPG',
      ConvertKind.pngToJpg,
      Color(0xFF2E7D32),
    ),
    (
      Icons.crop_original,
      'JPG to PNG',
      'Save a JPG as a PNG',
      ConvertKind.jpgToPng,
      Color(0xFF6A1B9A),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final body = FadeRiseIn(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
        children: [
          if (widget.embedded) ...[
            Text('Convert', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Pick a converter below — PDF, text, slides, or images.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final cross = constraints.maxWidth >= 360 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tiles.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cross,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: cross == 1 ? 3.2 : 1.55,
                ),
                itemBuilder: (context, i) {
                  final (icon, title, subtitle, kind, color) = _tiles[i];
                  return _tile(
                    icon: icon,
                    title: title,
                    subtitle: subtitle,
                    color: color,
                    kind: kind,
                  );
                },
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
                    duration: AppMotion.quick,
                    switchInCurve: AppMotion.emphasizedDecelerate,
                    switchOutCurve: AppMotion.emphasizedAccelerate,
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
                  if (_last!.mimeType == 'text/plain' ||
                      _last!.outputPath.toLowerCase().endsWith('.txt')) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Plain text (.txt) — open in ScanMe viewer',
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => FileViewerScreen.open(
                      context,
                      _last!.outputPath,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open in ScanMe'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _saveToDevice(_last!),
                    icon: const Icon(Icons.save_alt),
                    label: Text(
                      _last!.outputPath.toLowerCase().endsWith('.txt')
                          ? 'Save .txt to device'
                          : 'Save to device',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _share(_last!),
                    icon: const Icon(Icons.share_outlined),
                    label: Text('Share ${_last!.label}'),
                    style: OutlinedButton.styleFrom(
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
    );

    if (widget.embedded) {
      return SafeArea(child: body);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Convert')),
      body: body,
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ConvertKind kind,
  }) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      onTap: _busy ? null : () => _run(kind),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            radius: 22,
            child: Icon(icon, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _run(ConvertKind kind) async {
    final picked = await _pick(kind);
    if (picked == null) return;

    setState(() {
      _busy = true;
      _progress = 'Preparing file…';
      _last = null;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (mounted) {
        setState(() => _progress = switch (kind) {
            ConvertKind.pdfToTxt => 'Extracting text to .txt…',
            ConvertKind.txtToPdf => 'Building PDF…',
            ConvertKind.pptxToPdf => 'Converting slides…',
            ConvertKind.pngToJpg => 'Writing JPG…',
            ConvertKind.jpgToPng => 'Writing PNG…',
          });
      }
      final result = switch (kind) {
        ConvertKind.pdfToTxt =>
          await DocumentConverterService.pdfToTxt(picked),
        ConvertKind.txtToPdf =>
          await DocumentConverterService.txtToPdf(picked),
        ConvertKind.pptxToPdf =>
          await DocumentConverterService.pptxToPdf(picked),
        ConvertKind.pngToJpg =>
          await DocumentConverterService.imageToJpeg(picked),
        ConvertKind.jpgToPng =>
          await DocumentConverterService.imageToPng(picked),
      };
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _last = result;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.label} ready — save or share')),
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

  Future<String?> _pick(ConvertKind kind) async {
    final (exts, title) = switch (kind) {
      ConvertKind.pdfToTxt => (['pdf'], 'Select PDF'),
      ConvertKind.txtToPdf => (['txt', 'text', 'md', 'log'], 'Select text file'),
      ConvertKind.pptxToPdf => (['pptx'], 'Select PowerPoint'),
      ConvertKind.pngToJpg => (
          ['png', 'webp', 'bmp', 'gif'],
          'Select PNG / image',
        ),
      ConvertKind.jpgToPng => (['jpg', 'jpeg', 'jpe'], 'Select JPEG'),
    };

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: exts,
      dialogTitle: title,
    );
    if (file == null) return null;

    final path = file.path;
    if (path != null && path.isNotEmpty) return path;

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('empty');
      return DocumentConverterService.materializePath(
        preferredName: file.name,
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that file.')),
        );
      }
      return null;
    }
  }

  Future<void> _saveToDevice(ConvertResult result) async {
    try {
      var name = result.outputPath.split(Platform.pathSeparator).last;
      if (result.mimeType == 'text/plain' &&
          !name.toLowerCase().endsWith('.txt')) {
        name = '$name.txt';
      }
      final where = await DeviceSaveService.saveFile(
        sourcePath: result.outputPath,
        displayName: name,
        dialogTitle: 'Save ${result.label} to your phone',
      );
      if (!mounted) return;
      if (where == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save cancelled')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: $where')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    }
  }

  Future<void> _share(ConvertResult result) async {
    final name = result.outputPath.split(Platform.pathSeparator).last;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            result.outputPath,
            mimeType: result.mimeType,
            name: name,
          ),
        ],
        subject: name,
      ),
    );
  }
}
