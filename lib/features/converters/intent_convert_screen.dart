import 'package:flutter/material.dart';

import '../../shared/widgets/app_ui.dart';
import '../file_viewer/file_viewer_screen.dart';
import 'convert_catalog.dart';
import 'convert_result_panel.dart';
import 'convert_tool_chrome.dart';
import 'document_converter_service.dart';

enum IntentConvertKind {
  pdfToTxt,
  pdfToDocx,
  txtToPdf,
  pptxToPdf,
  docxToPdf,
  xlsxToCsv,
  xlsxToPdf,
  pngToJpg,
  jpgToPng,
  toJpg,
  toPng,
  toWebp,
  toGif,
  heicToJpg,
}

extension IntentConvertKindX on IntentConvertKind {
  ConvertToolId get toolId => switch (this) {
        IntentConvertKind.pdfToTxt => ConvertToolId.pdfToTxt,
        IntentConvertKind.pdfToDocx => ConvertToolId.pdfToDocx,
        IntentConvertKind.txtToPdf => ConvertToolId.txtToPdf,
        IntentConvertKind.pptxToPdf => ConvertToolId.pptxToPdf,
        IntentConvertKind.docxToPdf => ConvertToolId.docxToPdf,
        IntentConvertKind.xlsxToCsv => ConvertToolId.xlsxToCsv,
        IntentConvertKind.xlsxToPdf => ConvertToolId.xlsxToPdf,
        IntentConvertKind.pngToJpg || IntentConvertKind.toJpg =>
          ConvertToolId.toJpg,
        IntentConvertKind.jpgToPng || IntentConvertKind.toPng =>
          ConvertToolId.toPng,
        IntentConvertKind.toWebp => ConvertToolId.toWebp,
        IntentConvertKind.toGif => ConvertToolId.toGif,
        IntentConvertKind.heicToJpg => ConvertToolId.heicToJpg,
      };

  ConvertToolMeta get meta =>
      convertToolMeta(toolId) ??
      const ConvertToolMeta(
        id: ConvertToolId.toJpg,
        section: ConvertSectionId.images,
        title: 'Convert',
        subtitle: '',
        icon: Icons.swap_horiz,
        color: Color(0xFF455A64),
      );

  Future<ConvertResult> run(String path) => runSimpleConvert(toolId, path);

  String get progressLabel => meta.progressLabel;

  String get title => meta.title;
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
    final meta = widget.kind.meta;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(meta.title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ConvertToolHero(tool: meta),
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
                  Text(_progress, style: text.titleMedium),
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 20),
            AppEmptyState(
              title: 'Convert failed',
              subtitle: _error!,
              primaryLabel: 'Retry',
              onPrimary: _run,
              secondaryLabel: 'View original',
              onSecondary: () => FileViewerScreen.open(context, widget.path),
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
