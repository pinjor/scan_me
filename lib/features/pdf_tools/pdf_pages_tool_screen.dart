import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../shared/widgets/app_ui.dart';
import '../converters/convert_catalog.dart';
import '../converters/convert_tool_chrome.dart';
import '../converters/document_converter_service.dart';
import 'pdf_page_selector.dart';
import 'pdf_pick.dart';
import 'pdf_tools_catalog.dart';
import 'pdf_tools_exception.dart';
import 'pdf_tools_result_panel.dart';
import 'pdf_tools_service.dart';

class PdfPagesToolScreen extends StatefulWidget {
  const PdfPagesToolScreen({super.key, required this.tool});

  final PdfToolMeta tool;

  @override
  State<PdfPagesToolScreen> createState() => _PdfPagesToolScreenState();
}

enum _SplitMode { selected, ranges, everyPage }

class _PdfPagesToolScreenState extends State<PdfPagesToolScreen> {
  String? _path;
  int _pageCount = 0;
  Set<int> _selected = {};
  List<int> _order = [];
  Map<int, Uint8List> _thumbs = {};
  int _preview = 0;
  bool _busy = false;
  bool _loading = false;
  String? _progress;
  double? _progressValue;
  String? _error;
  List<ConvertResult> _results = [];

  _SplitMode _splitMode = _SplitMode.selected;
  final _ranges = <PdfRange>[];
  int _rangeStart = 0;
  int _rangeEnd = 0;

  int _rotateDegrees = 90;
  PdfImageExportFormat _imgFormat = PdfImageExportFormat.jpg;
  String _imgQuality = 'balanced';

  PdfToolId get _id => widget.tool.id;

  Future<void> _pick() async {
    final path = await pickSinglePdf(context);
    if (path == null || !mounted) return;
    await _load(path);
  }

  Future<void> _load(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _path = path;
    });
    try {
      final count = await PdfToolsService.pageCount(path);
      if (!mounted) return;
      final order = List<int>.generate(count, (i) => i);
      setState(() {
        _pageCount = count;
        _order = order;
        _selected = {};
        _preview = 0;
        _rangeStart = 0;
        _rangeEnd = count > 0 ? count - 1 : 0;
        _thumbs = {};
        _loading = false;
      });
      _loadThumbs();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _path = null;
        _error = '$e';
      });
    }
  }

  Future<void> _loadThumbs() async {
    final path = _path;
    if (path == null) return;
    final batch = [
      for (var i = 0; i < _pageCount && i < 48; i++) i,
    ];
    try {
      final thumbs = await PdfToolsService.thumbnails(
        path: path,
        indexes: batch,
        dpi: 64,
      );
      if (!mounted || _path != path) return;
      setState(() => _thumbs = thumbs);
    } catch (_) {
      // Placeholders stay — raster not always available.
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete these pages?'),
        content: Text(
          'Remove ${_selected.length} page${_selected.length == 1 ? '' : 's'} '
          'from a new copy. The original PDF stays unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete in new PDF'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run();
  }

  Future<void> _run() async {
    final path = _path;
    if (path == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _results = [];
      _progress = 'Working…';
    });
    try {
      final results = await _execute(path);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _progressValue = null;
        _results = results;
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

  Future<List<ConvertResult>> _execute(String path) async {
    onProgress(String label, double? p) {
      if (!mounted) return;
      setState(() {
        _progress = label;
        _progressValue = p;
      });
    }

    switch (_id) {
      case PdfToolId.split:
        return switch (_splitMode) {
          _SplitMode.everyPage => PdfToolsService.splitEveryPage(
              path: path,
              onProgress: onProgress,
            ),
          _SplitMode.ranges => PdfToolsService.splitRanges(
              path: path,
              ranges: List.of(_ranges),
              onProgress: onProgress,
            ),
          _SplitMode.selected => [
              await PdfToolsService.extractPages(
                path: path,
                indexes: _selected.toList(),
                kind: 'SPLIT',
                onProgress: onProgress,
              ),
            ],
        };
      case PdfToolId.reorder:
        return [
          await PdfToolsService.reorderPages(
            path: path,
            order: List.of(_order),
            onProgress: onProgress,
          ),
        ];
      case PdfToolId.deletePages:
        return [
          await PdfToolsService.deletePages(
            path: path,
            indexes: _selected,
            onProgress: onProgress,
          ),
        ];
      case PdfToolId.rotate:
        return [
          await PdfToolsService.rotatePages(
            path: path,
            indexes: _selected,
            degrees: _rotateDegrees,
            onProgress: onProgress,
          ),
        ];
      case PdfToolId.extract:
        return [
          await PdfToolsService.extractPages(
            path: path,
            indexes: _selected.toList(),
            onProgress: onProgress,
          ),
        ];
      case PdfToolId.pdfToImages:
        final all = _selected.isEmpty
            ? List<int>.generate(_pageCount, (i) => i)
            : _selected.toList();
        if (all.length > 40) {
          throw const PdfToolsException(
            'Exporting that many images at once can fill storage. '
            'Select 40 pages or fewer.',
          );
        }
        final (dpi, quality) = switch (_imgQuality) {
          'small' => (96.0, 55),
          'high' => (180.0, 90),
          _ => (130.0, 78),
        };
        return PdfToolsService.pdfToImages(
          path: path,
          indexes: all,
          format: _imgFormat,
          quality: quality,
          dpi: dpi,
          onProgress: onProgress,
        );
      default:
        throw const PdfToolsException('Unknown PDF tool.');
    }
  }

  String get _cta => switch (_id) {
        PdfToolId.split => 'Split PDF',
        PdfToolId.reorder => 'Save new PDF',
        PdfToolId.deletePages => 'Delete pages',
        PdfToolId.rotate => 'Save rotated PDF',
        PdfToolId.extract => 'Extract',
        PdfToolId.pdfToImages => 'Export images',
        _ => 'Continue',
      };

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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
            onPressed: _busy || _loading ? null : _pick,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_path == null ? 'Choose PDF' : 'Choose another PDF'),
            style: convertPrimaryButtonStyle(),
          ),
          if (_loading) ...[
            const SizedBox(height: 20),
            const AppProgressCard(
              title: 'Opening PDF',
              detail: 'Counting pages…',
            ),
          ],
          if (_path != null && !_loading) ...[
            const SizedBox(height: 16),
            Text(
              '$_pageCount page${_pageCount == 1 ? '' : 's'} · original stays unchanged',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            PdfPreviewPane(
              pageNumber: _preview + 1,
              bytes: _thumbs[_id == PdfToolId.reorder ? _order[_preview] : _preview],
            ),
            const SizedBox(height: 12),
            if (_id == PdfToolId.split) _splitControls(text, scheme),
            if (_id == PdfToolId.rotate) _rotateControls(),
            if (_id == PdfToolId.pdfToImages) _imageControls(),
            const SizedBox(height: 8),
            if (_id == PdfToolId.reorder)
              _reorderList()
            else if (!(_id == PdfToolId.split &&
                _splitMode == _SplitMode.everyPage))
              PdfPageSelector(
                pageCount: _pageCount,
                selected: _selected,
                thumbnails: _thumbs,
                previewIndex: _preview,
                onPreview: (i) => setState(() => _preview = i),
                onChanged: (s) => setState(() => _selected = s),
                multi: true,
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy
                  ? null
                  : (_id == PdfToolId.deletePages && _selected.isEmpty)
                      ? null
                      : (_id == PdfToolId.deletePages ? _confirmDelete : _run),
              style: convertPrimaryButtonStyle(),
              child: Text(_cta),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 20),
            AppProgressCard(
              title: _progress ?? tool.title,
              detail: 'Processing on this phone.',
              progress: _progressValue,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppEmptyState(
              title: 'Couldn’t finish',
              subtitle: _error!,
              primaryLabel: 'Try again',
              onPrimary: _path == null ? _pick : _run,
            ),
          ],
          if (_results.isNotEmpty && !_busy) ...[
            const SizedBox(height: 20),
            PdfToolsResultPanel(results: _results),
          ],
        ],
      ),
    );
  }

  Widget _splitControls(TextTheme text, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Selected pages'),
              selected: _splitMode == _SplitMode.selected,
              onSelected: (_) =>
                  setState(() => _splitMode = _SplitMode.selected),
            ),
            ChoiceChip(
              label: const Text('Ranges'),
              selected: _splitMode == _SplitMode.ranges,
              onSelected: (_) =>
                  setState(() => _splitMode = _SplitMode.ranges),
            ),
            ChoiceChip(
              label: const Text('Every page'),
              selected: _splitMode == _SplitMode.everyPage,
              onSelected: (_) =>
                  setState(() => _splitMode = _SplitMode.everyPage),
            ),
          ],
        ),
        if (_splitMode == _SplitMode.ranges) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _rangeStart,
                  decoration: const InputDecoration(labelText: 'From'),
                  items: [
                    for (var i = 0; i < _pageCount; i++)
                      DropdownMenuItem(value: i, child: Text('${i + 1}')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _rangeStart = v;
                      if (_rangeEnd < v) _rangeEnd = v;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _rangeEnd,
                  decoration: const InputDecoration(labelText: 'To'),
                  items: [
                    for (var i = _rangeStart; i < _pageCount; i++)
                      DropdownMenuItem(value: i, child: Text('${i + 1}')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _rangeEnd = v);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Add range',
                onPressed: () => setState(() {
                  _ranges.add(PdfRange(_rangeStart, _rangeEnd));
                }),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          ..._ranges.asMap().entries.map(
                (e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Range ${e.key + 1}: ${e.value.start + 1}–${e.value.end + 1}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _ranges.removeAt(e.key)),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _rotateControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('90° clockwise'),
              selected: _rotateDegrees == 90,
              onSelected: (_) => setState(() => _rotateDegrees = 90),
            ),
            ChoiceChip(
              label: const Text('90° counter-clockwise'),
              selected: _rotateDegrees == -90,
              onSelected: (_) => setState(() => _rotateDegrees = -90),
            ),
            ChoiceChip(
              label: const Text('180°'),
              selected: _rotateDegrees == 180,
              onSelected: (_) => setState(() => _rotateDegrees = 180),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selected.isEmpty
              ? 'No pages selected — all pages will rotate.'
              : '${_selected.length} page${_selected.length == 1 ? '' : 's'} will rotate.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _imageControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('JPG'),
              selected: _imgFormat == PdfImageExportFormat.jpg,
              onSelected: (_) =>
                  setState(() => _imgFormat = PdfImageExportFormat.jpg),
            ),
            ChoiceChip(
              label: const Text('PNG'),
              selected: _imgFormat == PdfImageExportFormat.png,
              onSelected: (_) =>
                  setState(() => _imgFormat = PdfImageExportFormat.png),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Small'),
              selected: _imgQuality == 'small',
              onSelected: (_) => setState(() => _imgQuality = 'small'),
            ),
            ChoiceChip(
              label: const Text('Balanced'),
              selected: _imgQuality == 'balanced',
              onSelected: (_) => setState(() => _imgQuality = 'balanced'),
            ),
            ChoiceChip(
              label: const Text('High'),
              selected: _imgQuality == 'high',
              onSelected: (_) => setState(() => _imgQuality = 'high'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _selected.isEmpty
              ? 'No selection — all pages export.'
              : '${_selected.length} page${_selected.length == 1 ? '' : 's'} selected.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _reorderList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _order.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _order.removeAt(oldIndex);
          _order.insert(newIndex, item);
          _preview = newIndex.clamp(0, _order.length - 1);
        });
      },
      itemBuilder: (context, i) {
        final page = _order[i];
        final thumb = _thumbs[page];
        return ListTile(
          key: ValueKey('p$page-$i'),
          leading: SizedBox(
            width: 36,
            height: 48,
            child: thumb != null
                ? Image.memory(thumb, fit: BoxFit.cover)
                : const Icon(Icons.drag_handle),
          ),
          title: Text('Page ${page + 1}'),
          subtitle: Text('Position ${i + 1}'),
          trailing: const Icon(Icons.drag_handle),
          onTap: () => setState(() => _preview = i),
        );
      },
    );
  }
}
