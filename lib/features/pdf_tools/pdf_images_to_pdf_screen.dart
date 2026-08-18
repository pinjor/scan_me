import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/widgets/app_ui.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_chrome.dart';
import '../converters/document_converter_service.dart';
import 'pdf_tools_catalog.dart';
import 'pdf_tools_result_panel.dart';
import 'pdf_tools_service.dart';

/// Direct Images → PDF. Uses the same JPEG prep + PDF writer as scan export.
class PdfImagesToPdfScreen extends StatefulWidget {
  const PdfImagesToPdfScreen({super.key, required this.tool});

  final PdfToolMeta tool;

  @override
  State<PdfImagesToPdfScreen> createState() => _PdfImagesToPdfScreenState();
}

class _PdfImagesToPdfScreenState extends State<PdfImagesToPdfScreen> {
  final _paths = <String>[];
  bool _busy = false;
  String? _progress;
  double? _progressValue;
  String? _error;
  ConvertResult? _result;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 95);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _paths
        ..clear()
        ..addAll(picked.map((x) => x.path));
      _result = null;
      _error = null;
    });
  }

  Future<void> _run() async {
    if (_paths.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await PdfToolsService.imagesToPdf(
        imagePaths: List.of(_paths),
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
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(_paths.isEmpty ? 'Choose photos' : 'Choose other photos'),
            style: convertPrimaryButtonStyle(),
          ),
          if (_paths.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '${_paths.length} image${_paths.length == 1 ? '' : 's'} · drag to reorder',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paths.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _paths.removeAt(oldIndex);
                  _paths.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final path = _paths[i];
                return ListTile(
                  key: ValueKey('$i|$path'),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(path),
                      width: 40,
                      height: 52,
                      fit: BoxFit.cover,
                      cacheWidth: 80,
                      errorBuilder: (_, _, _) => const Icon(Icons.image),
                    ),
                  ),
                  title: Text(
                    path.split(Platform.pathSeparator).last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _paths.removeAt(i)),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _run,
              style: convertPrimaryButtonStyle(),
              child: const Text('Create PDF'),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 20),
            AppProgressCard(
              title: _progress ?? 'Building PDF',
              detail: 'Same quality path as ScanMe export.',
              progress: _progressValue,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppEmptyState(
              title: 'Couldn’t create PDF',
              subtitle: _error!,
              primaryLabel: 'Try again',
              onPrimary: _run,
            ),
          ],
          if (_result != null && !_busy) ...[
            const SizedBox(height: 20),
            PdfToolsResultPanel(results: [_result!]),
          ],
        ],
      ),
    );
  }
}
