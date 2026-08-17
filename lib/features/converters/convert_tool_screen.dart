import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/app_ui.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';

/// Pick a file and run a one-shot converter (format / office).
class ConvertToolScreen extends StatefulWidget {
  const ConvertToolScreen({
    super.key,
    required this.tool,
    this.initialPath,
  });

  final ConvertToolMeta tool;
  final String? initialPath;

  @override
  State<ConvertToolScreen> createState() => _ConvertToolScreenState();
}

class _ConvertToolScreenState extends State<ConvertToolScreen> {
  bool _busy = false;
  String? _progress;
  ConvertResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    final path = widget.initialPath;
    if (path != null && path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runPath(path));
    }
  }

  Future<void> _pickAndRun() async {
    final (exts, title) = pickHintsFor(widget.tool.id);
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: exts,
      dialogTitle: title,
    );
    if (file == null) return;

    var path = file.path;
    if (path == null || path.isEmpty) {
      try {
        final bytes = await file.readAsBytes();
        path = await DocumentConverterService.materializePath(
          preferredName: file.name,
          bytes: bytes,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that file.')),
        );
        return;
      }
    }
    await _runPath(path);
  }

  Future<void> _runPath(String path) async {
    setState(() {
      _busy = true;
      _progress = widget.tool.progressLabel;
      _result = null;
      _error = null;
    });

    try {
      final result = await runSimpleConvert(widget.tool.id, path);
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
        _progress = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tool = widget.tool;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(tool.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ConvertToolHero(tool: tool),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _pickAndRun,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_result == null ? 'Choose file' : 'Convert another'),
            style: convertPrimaryButtonStyle(),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            AppCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 14),
                  Text(_progress ?? tool.progressLabel, style: text.titleMedium),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 20),
            AppEmptyState(
              title: 'Convert failed',
              subtitle: _error!,
              primaryLabel: 'Try again',
              onPrimary: _pickAndRun,
            ),
          ],
          if (_result != null && !_busy) ...[
            const SizedBox(height: 20),
            ConvertResultPanel(result: _result!),
          ],
        ],
      ),
    );
  }
}
