import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../document_editor/editor_controller.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late final TextEditingController _nameController;
  late ExportSettings _settings;
  bool _busy = false;
  String? _progress;
  bool _moreOptions = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(editorSessionProvider);
    final name = session?.name ?? 'Scanned document';
    _nameController = TextEditingController(text: name);
    _settings = ExportSettings(
      currentPageIndex: session?.selectedIndex ?? 0,
      selectedPageIndexes: {
        for (var i = 0; i < (session?.pages.length ?? 0); i++) i,
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final pageCount = session?.pages.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: const Text('Save document'),
      ),
      body: session == null
          ? const AppEmptyState(
              title: 'Nothing to save',
              subtitle: 'Go back and capture or import pages first.',
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      Text('Document name', style: text.titleSmall),
                      const SizedBox(height: 6),
                      AppCard(
                        elevated: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          enabled: !_busy,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            isDense: true,
                            hintText: 'Document name',
                          ),
                          style: text.titleMedium,
                          onChanged: (v) => ref
                              .read(editorSessionProvider.notifier)
                              .setName(v),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Save as · $pageCount '
                        '${pageCount == 1 ? 'page' : 'pages'}',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _FormatTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'PDF',
                        subtitle: 'Best for sharing and printing',
                        value: _settings.createPdf,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.createPdf = v),
                      ),
                      const SizedBox(height: 10),
                      _FormatTile(
                        icon: Icons.photo_library_outlined,
                        title: 'Images',
                        subtitle: 'JPG or PNG files for each page',
                        value: _settings.saveImages,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.saveImages = v),
                      ),
                      const SizedBox(height: 10),
                      _FormatTile(
                        icon: Icons.folder_outlined,
                        title: 'Also save to device',
                        subtitle: 'Choose folder and name in your file manager',
                        value: _settings.alsoSaveToDevice,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.alsoSaveToDevice = v),
                      ),
                      const SizedBox(height: 12),
                      AppCard(
                        elevated: false,
                        onTap: _busy
                            ? null
                            : () => setState(() => _moreOptions = !_moreOptions),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune,
                              color: scheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'More options',
                                style: text.titleMedium,
                              ),
                            ),
                            Icon(
                              _moreOptions
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      if (_moreOptions) ...[
                        const SizedBox(height: 16),
                        if (_settings.createPdf) ...[
                          _sectionLabel(context, 'PDF quality'),
                          _chipRowWithHint<PdfQualityPreset>(
                            values: PdfQualityPreset.values,
                            labelOf: (v) => v.label,
                            hintOf: (v) => switch (v) {
                              PdfQualityPreset.small => 'Best for sharing',
                              PdfQualityPreset.balanced => 'Recommended',
                              PdfQualityPreset.high => 'Best for printing',
                            },
                            selected: _settings.pdfQuality,
                            onSelect: (v) =>
                                setState(() => _settings.pdfQuality = v),
                          ),
                          const SizedBox(height: 12),
                          _sectionLabel(context, 'Page size'),
                          _chipRow<PdfPageSizeOption>(
                            values: PdfPageSizeOption.values,
                            labelOf: (v) => v.label,
                            selected: _settings.pdfPageSize,
                            onSelect: (v) =>
                                setState(() => _settings.pdfPageSize = v),
                          ),
                          const SizedBox(height: 12),
                          _sectionLabel(context, 'Orientation'),
                          _chipRow<PdfOrientationOption>(
                            values: PdfOrientationOption.values,
                            labelOf: (v) => v.label,
                            selected: _settings.pdfOrientation,
                            onSelect: (v) =>
                                setState(() => _settings.pdfOrientation = v),
                          ),
                        ],
                        if (_settings.saveImages) ...[
                          if (_settings.createPdf) const SizedBox(height: 16),
                          _sectionLabel(context, 'Image format'),
                          _chipRow<ImageExportFormat>(
                            values: ImageExportFormat.values,
                            labelOf: (v) =>
                                v == ImageExportFormat.jpg ? 'JPG' : 'PNG',
                            selected: _settings.imageFormat,
                            onSelect: (v) =>
                                setState(() => _settings.imageFormat = v),
                          ),
                          const SizedBox(height: 12),
                          _sectionLabel(context, 'Image quality'),
                          _chipRowWithHint<ImageExportQuality>(
                            values: ImageExportQuality.values,
                            labelOf: (v) => v.label,
                            hintOf: (v) => v.hint,
                            selected: _settings.imageQuality,
                            onSelect: (v) =>
                                setState(() => _settings.imageQuality = v),
                          ),
                          const SizedBox(height: 12),
                          _sectionLabel(context, 'Which pages'),
                          _chipRow<ImageExportScope>(
                            values: ImageExportScope.values,
                            labelOf: (v) => v.label,
                            selected: _settings.imageScope,
                            onSelect: (v) =>
                                setState(() => _settings.imageScope = v),
                          ),
                          if (_settings.imageScope ==
                              ImageExportScope.selectedPages) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (var i = 0; i < pageCount; i++)
                                  FilterChip(
                                    label: Text('Page ${i + 1}'),
                                    selected: _settings.selectedPageIndexes
                                        .contains(i),
                                    onSelected: _busy
                                        ? null
                                        : (sel) {
                                            setState(() {
                                              final next = {
                                                ..._settings.selectedPageIndexes,
                                              };
                                              if (sel) {
                                                next.add(i);
                                              } else {
                                                next.remove(i);
                                              }
                                              _settings.selectedPageIndexes =
                                                  next;
                                            });
                                          },
                                  ),
                              ],
                            ),
                          ],
                        ],
                        if (!_settings.createPdf && !_settings.saveImages)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Turn on PDF or Images above to see more options.',
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                      if (_progress != null) ...[
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: AppMotion.medium,
                          child: AppProgressCard(
                            key: ValueKey(_progress),
                            title: 'Saving document',
                            detail: _progress!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ||
                                (!_settings.createPdf && !_settings.saveImages)
                            ? null
                            : _export,
                        icon: Icon(_busy ? Icons.hourglass_top : Icons.save_alt),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                        label: Text(_busy ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }

  Widget _chipRow<T>({
    required List<T> values,
    required String Function(T) labelOf,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: selected == v,
            onSelected: _busy
                ? null
                : (sel) {
                    if (sel) onSelect(v);
                  },
          ),
      ],
    );
  }

  Widget _chipRowWithHint<T>({
    required List<T> values,
    required String Function(T) labelOf,
    required String Function(T) hintOf,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chipRow(
          values: values,
          labelOf: labelOf,
          selected: selected,
          onSelect: onSelect,
        ),
        const SizedBox(height: 6),
        Text(
          hintOf(selected),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _progress = 'Preparing pages…';
    });
    ref.read(editorSessionProvider.notifier).setName(_nameController.text);
    _settings.currentPageIndex =
        ref.read(editorSessionProvider)?.selectedIndex ?? 0;
    try {
      await ref.read(editorSessionProvider.notifier).export(
            settings: _settings,
            onProgress: (label) {
              if (mounted) setState(() => _progress = label);
            },
          );
      if (!mounted) return;
      final parts = <String>[
        if (_settings.createPdf) 'PDF',
        if (_settings.saveImages) 'Images',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Document saved · ${parts.join(' · ')}'
            '${_settings.alsoSaveToDevice ? ' · pick a folder for device copy' : ''}',
          ),
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(editorSessionProvider.notifier).clear();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Something went wrong while saving this document. Try again.',
            ),
          ),
        );
      }
    }
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AppCard(
      elevated: false,
      onTap: enabled ? () => onChanged(!value) : null,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      color: value
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surface,
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
