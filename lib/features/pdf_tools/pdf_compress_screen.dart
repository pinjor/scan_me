import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/widgets/app_ui.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_chrome.dart';
import 'pdf_pick.dart';
import 'pdf_tools_catalog.dart';
import 'pdf_tools_result_panel.dart';
import 'pdf_tools_service.dart';

class PdfCompressScreen extends StatefulWidget {
  const PdfCompressScreen({super.key, required this.tool});

  final PdfToolMeta tool;

  @override
  State<PdfCompressScreen> createState() => _PdfCompressScreenState();
}

class _PdfCompressScreenState extends State<PdfCompressScreen> {
  String? _path;
  int? _originalBytes;
  int? _pageCount;
  PdfCompressPreset _preset = PdfCompressPreset.balanced;
  bool _busy = false;
  String? _progress;
  double? _progressValue;
  String? _error;
  PdfCompressOutcome? _outcome;

  Future<void> _pick() async {
    final path = await pickSinglePdf();
    if (path == null || !mounted) return;
    try {
      final bytes = await File(path).length();
      final pages = await PdfToolsService.pageCount(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _originalBytes = bytes;
        _pageCount = pages;
        _error = null;
        _outcome = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _path = null;
        _error = '$e';
      });
    }
  }

  Future<void> _run() async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
      _progress = 'Compressing…';
    });
    try {
      final outcome = await PdfToolsService.compress(
        path: path,
        preset: _preset,
        onProgress: (label, p) {
          if (!mounted) return;
          setState(() {
            _progress = label;
            _progressValue = p;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _outcome = outcome;
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
    final tool = widget.tool;
    final meta = ConvertToolMeta(
      id: ConvertToolId.pdfTools,
      section: ConvertSectionId.pdfTools,
      title: tool.title,
      subtitle: tool.subtitle,
      icon: tool.icon,
      color: tool.color,
      steps: tool.steps,
    );
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final name = _path?.split(Platform.pathSeparator).last;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(tool.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ConvertToolHero(tool: meta),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_path == null ? 'Choose PDF' : 'Choose another PDF'),
            style: convertPrimaryButtonStyle(),
          ),
          if (_path != null) ...[
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name ?? '', style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (_pageCount != null)
                        '$_pageCount page${_pageCount == 1 ? '' : 's'}',
                      if (_originalBytes != null)
                        'Original ${PdfToolsService.friendlySize(_originalBytes!)}',
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Compression', style: text.titleSmall),
            const SizedBox(height: 8),
            for (final preset in PdfCompressPreset.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  elevated: false,
                  onTap: _busy
                      ? null
                      : () => setState(() => _preset = preset),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _preset == preset
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preset.title, style: text.titleSmall),
                            Text(
                              preset.subtitle,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'ScanMe will keep the smaller result. If the file is already tight, size may stay the same.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _run,
              style: convertPrimaryButtonStyle(),
              child: const Text('Compress PDF'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 20),
            AppProgressCard(
              title: _progress ?? 'Compressing',
              detail: 'Original file is not overwritten.',
              progress: _progressValue,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppEmptyState(
              title: 'Couldn’t compress',
              subtitle: _error!,
              primaryLabel: 'Try again',
              onPrimary: _path == null ? _pick : _run,
            ),
          ],
          if (_outcome != null && !_busy) ...[
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Original: ${PdfToolsService.friendlySize(_outcome!.originalBytes)}'),
                  Text('New: ${PdfToolsService.friendlySize(_outcome!.newBytes)}'),
                  Text(
                    _outcome!.savedBytes > 0
                        ? 'Saved: ${(_outcome!.savedRatio * 100).toStringAsFixed(1)}%'
                        : 'Already as small as ScanMe can make it.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PdfToolsResultPanel(results: [_outcome!.result]),
          ],
        ],
      ),
    );
  }
}
