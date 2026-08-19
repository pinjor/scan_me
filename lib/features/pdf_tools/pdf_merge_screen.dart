import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/widgets/app_ui.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_chrome.dart';
import '../converters/document_converter_service.dart';
import 'pdf_pick.dart';
import 'pdf_tools_catalog.dart';
import 'pdf_tools_exception.dart';
import 'pdf_tools_result_panel.dart';
import 'pdf_tools_service.dart';

class PdfMergeScreen extends StatefulWidget {
  const PdfMergeScreen({super.key, required this.tool});

  final PdfToolMeta tool;

  @override
  State<PdfMergeScreen> createState() => _PdfMergeScreenState();
}

class _PdfMergeScreenState extends State<PdfMergeScreen> {
  final _files = <String>[];
  bool _busy = false;
  String? _progress;
  double? _progressValue;
  String? _error;
  ConvertResult? _result;

  Future<void> _pick() async {
    final picked = await pickManyPdfs(context);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _files
        ..clear()
        ..addAll(picked);
      _result = null;
      _error = null;
    });
  }

  Future<void> _merge() async {
    if (_files.length < 2) {
      setState(() => _error = PdfToolsException.tooFew().message);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _progress = 'Merging PDFs…';
    });
    try {
      final result = await PdfToolsService.merge(
        paths: List.of(_files),
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
        _progressValue = null;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
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
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_files.isEmpty ? 'Choose PDFs' : 'Choose other PDFs'),
            style: convertPrimaryButtonStyle(),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Merge order · ${_files.length} files',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _files.removeAt(oldIndex);
                  _files.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final name = _files[i].split(Platform.pathSeparator).last;
                return ListTile(
                  key: ValueKey(_files[i]),
                  leading: CircleAvatar(
                    radius: 14,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.close),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _files.removeAt(i)),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _merge,
              style: convertPrimaryButtonStyle(),
              child: const Text('Merge PDFs'),
            ),
            const SizedBox(height: 8),
            Text(
              'Saves a new file. Original PDFs stay unchanged.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 20),
            AppProgressCard(
              title: _progress ?? 'Merging PDFs',
              detail: 'Keeping this phone busy — files stay on device.',
              progress: _progressValue,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppEmptyState(
              title: 'Couldn’t merge',
              subtitle: _error!,
              primaryLabel: 'Try again',
              onPrimary: _merge,
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
