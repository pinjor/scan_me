import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:photo_view/photo_view.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../../core/services/device_save_service.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../core/theme/app_theme.dart';

enum FileViewerKind { txt, pdf, image, pptx, docx, unknown }

FileViewerKind fileViewerKindForPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return switch (ext) {
    '.txt' || '.text' || '.md' || '.log' || '.csv' => FileViewerKind.txt,
    '.pdf' => FileViewerKind.pdf,
    '.png' || '.jpg' || '.jpeg' || '.jpe' || '.webp' || '.gif' || '.bmp' ||
    '.heic' || '.heif' =>
      FileViewerKind.image,
    '.pptx' => FileViewerKind.pptx,
    '.docx' => FileViewerKind.docx,
    _ => FileViewerKind.unknown,
  };
}

/// In-app viewer for convert outputs and picked files
/// (.txt / PDF / image / PPTX / DOCX).
class FileViewerScreen extends StatefulWidget {
  const FileViewerScreen({
    super.key,
    required this.path,
    this.title,
  });

  final String path;
  final String? title;

  static Future<void> open(BuildContext context, String path, {String? title}) {
    return AppPageRoute.push(
      context,
      FileViewerScreen(path: path, title: title),
    );
  }

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  late final FileViewerKind _kind = fileViewerKindForPath(widget.path);

  String get _name =>
      widget.title ?? p.basename(widget.path);

  Future<void> _save() async {
    try {
      final where = await DeviceSaveService.saveFile(sourcePath: widget.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(where == null ? 'Save cancelled' : 'Saved to device')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while saving. Try again.'),
        ),
      );
    }
  }

  Future<void> _share() async {
    final mime = switch (_kind) {
      FileViewerKind.txt => 'text/plain',
      FileViewerKind.pdf => 'application/pdf',
      FileViewerKind.pptx =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      FileViewerKind.docx =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      FileViewerKind.image => null,
      FileViewerKind.unknown => null,
    };
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(widget.path, mimeType: mime, name: _name),
        ],
        subject: _name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Save to device',
            onPressed: _save,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: FadeRiseIn(
        child: switch (_kind) {
          FileViewerKind.txt => _TxtBody(path: widget.path),
          FileViewerKind.pdf => _PdfBody(path: widget.path),
          FileViewerKind.image => _ImageBody(path: widget.path),
          FileViewerKind.pptx => _PptxBody(path: widget.path),
          FileViewerKind.docx => _DocxBody(path: widget.path),
          FileViewerKind.unknown => AppEmptyState(
              title: 'Cannot preview this file',
              subtitle: _name,
            ),
        },
      ),
    );
  }
}

class _TxtBody extends StatefulWidget {
  const _TxtBody({required this.path});
  final String path;

  @override
  State<_TxtBody> createState() => _TxtBodyState();
}

class _TxtBodyState extends State<_TxtBody> {
  late final Future<String> _future = _load();

  Future<String> _load() async {
    final bytes = await File(widget.path).readAsBytes();
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FutureBuilder<String>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppEmptyState(
            title: 'Could not read file',
            subtitle: 'Try opening it again, or save a new copy.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SelectionArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Text(
              snap.data!,
              style: text.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
                color: scheme.onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PdfBody extends StatelessWidget {
  const _PdfBody({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: (_) => File(path).readAsBytes(),
      allowPrinting: false,
      allowSharing: false,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      useActions: false,
      pdfFileName: p.basename(path),
      loadingWidget: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final file = File(path);
    if (!file.existsSync()) {
      return const AppEmptyState(
        title: 'Image missing',
        subtitle: 'This file could not be found on the device.',
      );
    }
    return ColoredBox(
      color: scheme.surfaceContainerLowest,
      child: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: BoxDecoration(color: scheme.surface),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
      ),
    );
  }
}

class _PptxSlide {
  _PptxSlide({required this.texts, required this.images});
  final List<String> texts;
  final List<Uint8List> images;
}

class _PptxBody extends StatefulWidget {
  const _PptxBody({required this.path});
  final String path;

  @override
  State<_PptxBody> createState() => _PptxBodyState();
}

class _PptxBodyState extends State<_PptxBody> {
  late final Future<List<_PptxSlide>> _future = _parse();
  var _page = 0;

  Future<List<_PptxSlide>> _parse() async {
    final bytes = await File(widget.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final slides = archive.files
        .where(
          (f) =>
              f.isFile &&
              RegExp(r'^ppt/slides/slide\d+\.xml$', caseSensitive: false)
                  .hasMatch(f.name.replaceAll('\\', '/')),
        )
        .toList()
      ..sort((a, b) {
        final na = int.tryParse(
              RegExp(r'slide(\d+)', caseSensitive: false)
                      .firstMatch(a.name)
                      ?.group(1) ??
                  '',
            ) ??
            0;
        final nb = int.tryParse(
              RegExp(r'slide(\d+)', caseSensitive: false)
                      .firstMatch(b.name)
                      ?.group(1) ??
                  '',
            ) ??
            0;
        return na.compareTo(nb);
      });

    if (slides.isEmpty) {
      throw StateError('No slides found in this PowerPoint file.');
    }

    final media = <String, Uint8List>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final name = f.name.replaceAll('\\', '/');
      if (name.startsWith('ppt/media/')) {
        media[p.basename(name).toLowerCase()] = Uint8List.fromList(f.content);
      }
    }

    final out = <_PptxSlide>[];
    for (final slideFile in slides) {
      final xml = XmlDocument.parse(
        String.fromCharCodes(slideFile.content as List<int>),
      );
      final texts = xml
          .descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 't')
          .map((e) => e.innerText.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final slideName = p.basename(slideFile.name);
      final relPath = 'ppt/slides/_rels/$slideName.xml.rels';
      final images = <Uint8List>[];
      ArchiveFile? relFile;
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name.replaceAll('\\', '/').toLowerCase() ==
            relPath.toLowerCase()) {
          relFile = f;
          break;
        }
      }
      if (relFile != null) {
        final relXml = XmlDocument.parse(
          String.fromCharCodes(relFile.content as List<int>),
        );
        for (final rel in relXml.findAllElements('Relationship')) {
          final target = rel.getAttribute('Target') ?? '';
          if (!target.contains('media/')) continue;
          final key = p.basename(target).toLowerCase();
          final data = media[key];
          if (data != null) images.add(data);
        }
      }
      out.add(_PptxSlide(texts: texts, images: images));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FutureBuilder<List<_PptxSlide>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppEmptyState(
            title: 'Could not open PowerPoint',
            subtitle: 'The file may be damaged or unsupported.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final slides = snap.data!;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Slide preview (text + images). Layout may differ from PowerPoint.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: PageView.builder(
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final slide = slides[i];
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text(
                        'Slide ${i + 1}',
                        style: text.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (slide.texts.isEmpty && slide.images.isEmpty)
                        Text(
                          '(Empty slide)',
                          style: text.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      for (final t in slide.texts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(t, style: text.bodyLarge),
                        ),
                      for (final im in slide.images)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            child: Image.memory(im, fit: BoxFit.contain),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: AppCard(
                  elevated: false,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Slide ${_page + 1} of ${slides.length}',
                    textAlign: TextAlign.center,
                    style: text.labelLarge,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Text preview of Word (.docx) — same chrome as txt / PPTX preview.
class _DocxBody extends StatefulWidget {
  const _DocxBody({required this.path});
  final String path;

  @override
  State<_DocxBody> createState() => _DocxBodyState();
}

class _DocxBodyState extends State<_DocxBody> {
  late final Future<List<String>> _future = _parse();

  Future<List<String>> _parse() async {
    final bytes = await File(widget.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      throw StateError('Not a valid Word file.');
    }
    final xml = XmlDocument.parse(utf8.decode(docFile.content as List<int>));
    final paragraphs = <String>[];
    for (final pNode in xml.findAllElements('p', namespaceUri: '*')) {
      final parts = pNode
          .findAllElements('t', namespaceUri: '*')
          .map((t) => t.innerText)
          .join();
      paragraphs.add(parts);
    }
    if (paragraphs.every((p) => p.trim().isEmpty)) {
      throw StateError('No readable text in this Word file.');
    }
    return paragraphs;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return const AppEmptyState(
            title: 'Could not open Word file',
            subtitle: 'The file may be damaged or unsupported.',
          );
        }
        if (!snap.hasData) {
          return const AppLoadingState(message: 'Opening document…');
        }
        final paragraphs = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Text preview. Open in Word for full editing.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: SelectionArea(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: paragraphs.length,
                  itemBuilder: (context, i) {
                    final line = paragraphs[i];
                    if (line.trim().isEmpty) {
                      return const SizedBox(height: 12);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        line,
                        style: text.bodyLarge?.copyWith(height: 1.45),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
