import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/device_save_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../file_viewer/file_viewer_screen.dart';
import 'document_converter_service.dart';

enum IntentConvertKind {
  pdfToTxt,
  txtToPdf,
  pptxToPdf,
  pngToJpg,
  jpgToPng,
}

extension IntentConvertKindX on IntentConvertKind {
  Future<ConvertResult> run(String path) => switch (this) {
        IntentConvertKind.pdfToTxt => DocumentConverterService.pdfToTxt(path),
        IntentConvertKind.txtToPdf => DocumentConverterService.txtToPdf(path),
        IntentConvertKind.pptxToPdf => DocumentConverterService.pptxToPdf(path),
        IntentConvertKind.pngToJpg => DocumentConverterService.imageToJpeg(path),
        IntentConvertKind.jpgToPng => DocumentConverterService.imageToPng(path),
      };

  String get progressLabel => switch (this) {
        IntentConvertKind.pdfToTxt => 'Extracting text to .txt…',
        IntentConvertKind.txtToPdf => 'Building PDF…',
        IntentConvertKind.pptxToPdf => 'Converting slides…',
        IntentConvertKind.pngToJpg => 'Writing JPG…',
        IntentConvertKind.jpgToPng => 'Writing PNG…',
      };

  String get title => switch (this) {
        IntentConvertKind.pdfToTxt => 'PDF to .txt',
        IntentConvertKind.txtToPdf => '.txt to PDF',
        IntentConvertKind.pptxToPdf => 'PPTX to PDF',
        IntentConvertKind.pngToJpg => 'PNG to JPG',
        IntentConvertKind.jpgToPng => 'JPG to PNG',
      };
}

/// Runs a convert started from Android “Open with” tool alias.
class IntentConvertScreen extends StatefulWidget {
  const IntentConvertScreen({
    super.key,
    required this.path,
    required this.kind,
  });

  final String path;
  final IntentConvertKind kind;

  @override
  State<IntentConvertScreen> createState() => _IntentConvertScreenState();
}

class _IntentConvertScreenState extends State<IntentConvertScreen> {
  bool _busy = true;
  String _progress = 'Preparing file…';
  ConvertResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _progress = widget.kind.progressLabel;
      _error = null;
      _result = null;
    });
    try {
      final result = await widget.kind.run(widget.path);
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
      appBar: AppBar(title: Text(widget.kind.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: _busy
            ? AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(_progress, style: text.titleMedium),
                  ],
                ),
              )
            : _error != null
                ? AppEmptyState(
                    title: 'Convert failed',
                    subtitle: _error!,
                    primaryLabel: 'Retry',
                    onPrimary: _run,
                    secondaryLabel: 'View original',
                    onSecondary: () => FileViewerScreen.open(
                      context,
                      widget.path,
                    ),
                  )
                : AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ready', style: text.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          _result!.outputPath
                              .split(Platform.pathSeparator)
                              .last,
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => FileViewerScreen.open(
                            context,
                            _result!.outputPath,
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
                          onPressed: () => _save(_result!),
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Save to device'),
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
                          onPressed: () => _share(_result!),
                          icon: const Icon(Icons.share_outlined),
                          label: Text('Share ${_result!.label}'),
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
      ),
    );
  }

  Future<void> _save(ConvertResult result) async {
    try {
      final where = await DeviceSaveService.saveFile(
        sourcePath: result.outputPath,
        displayName: result.outputPath.split(Platform.pathSeparator).last,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(where == null ? 'Save cancelled' : 'Saved: $where'),
        ),
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
