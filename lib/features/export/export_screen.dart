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

  @override
  void initState() {
    super.initState();
    final session = ref.read(editorSessionProvider);
    final name = session?.name ?? 'Scan';
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
    final pageCount = session?.pages.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Save document')),
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
                      Text('Name', style: text.titleSmall),
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
                      const SizedBox(height: 16),
                      Text(
                        'Format · $pageCount '
                        '${pageCount == 1 ? 'page' : 'pages'}',
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _FormatTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'PDF',
                        value: _settings.createPdf,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.createPdf = v),
                      ),
                      if (_settings.createPdf) ...[
                        const SizedBox(height: 12),
                        _sectionLabel(context, 'PDF quality'),
                        _chipRow<PdfQualityPreset>(
                          values: PdfQualityPreset.values,
                          labelOf: (v) => v.label,
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
                      const SizedBox(height: 10),
                      _FormatTile(
                        icon: Icons.photo_library_outlined,
                        title: 'Images',
                        value: _settings.saveImages,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.saveImages = v),
                      ),
                      if (_settings.saveImages) ...[
                        const SizedBox(height: 12),
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
                        _chipRow<ImageExportQuality>(
                          values: ImageExportQuality.values,
                          labelOf: (v) => v.label,
                          selected: _settings.imageQuality,
                          onSelect: (v) =>
                              setState(() => _settings.imageQuality = v),
                        ),
                        const SizedBox(height: 12),
                        _sectionLabel(context, 'Export pages'),
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
                      const SizedBox(height: 10),
                      _FormatTile(
                        icon: Icons.folder_outlined,
                        title: 'Also save to device',
                        subtitle:
                            'Opens your file manager so you choose folder & name',
                        value: _settings.alsoSaveToDevice,
                        enabled: !_busy,
                        onChanged: (v) =>
                            setState(() => _settings.alsoSaveToDevice = v),
                      ),
                      if (_progress != null) ...[
                        const SizedBox(height: 28),
                        AnimatedSwitcher(
                          duration: AppMotion.medium,
                          child: AppCard(
                            key: ValueKey(_progress),
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _progress!,
                                  textAlign: TextAlign.center,
                                  style: text.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(minHeight: 3),
                              ],
                            ),
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
                      child: FilledButton(
                        onPressed: _busy ||
                                (!_settings.createPdf && !_settings.saveImages)
                            ? null
                            : _export,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                        ),
                        child: Text(
                          _busy ? 'Saving…' : 'Save',
                        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _settings.alsoSaveToDevice
                ? 'Saved to library — pick a folder in the file manager for device copy'
                : 'Saved to library',
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
          SnackBar(content: Text('Could not save: $e')),
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
