import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../document_editor/editor_controller.dart';

/// Pick pages and save JPGs to the device.
class ExportImageScreen extends ConsumerStatefulWidget {
  const ExportImageScreen({super.key});

  @override
  ConsumerState<ExportImageScreen> createState() => _ExportImageScreenState();
}

class _ExportImageScreenState extends ConsumerState<ExportImageScreen> {
  late Set<int> _selectedPages;
  bool _busy = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    final n = ref.read(editorSessionProvider)?.pages.length ?? 0;
    _selectedPages = {for (var i = 0; i < n; i++) i};
  }

  ExportSettings _settings() {
    final session = ref.read(editorSessionProvider);
    final selected = _selectedPages.isEmpty
        ? {0}
        : Set<int>.from(_selectedPages);
    return ExportSettings(
      createPdf: false,
      saveImages: true,
      alsoSaveToDevice: true,
      currentPageIndex: session?.selectedIndex ?? 0,
      imageScope: ImageExportScope.selectedPages,
      selectedPageIndexes: selected,
      imageFormat: ImageExportFormat.jpg,
      imageQuality: ImageExportQuality.high,
    );
  }

  Future<void> _save() async {
    final session = ref.read(editorSessionProvider);
    if (session == null) return;
    if (_selectedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one page.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _progress = 'Preparing…';
    });
    try {
      final outcome = await ref.read(editorSessionProvider.notifier).export(
            settings: _settings(),
            onProgress: (label) {
              if (mounted) setState(() => _progress = label);
            },
          );
      if (!mounted) return;
      final deviceNote = outcome.deviceSavedCount > 0
          ? ' · saved to device'
          : ' · device copy skipped';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Images saved$deviceNote')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
      ref.read(editorSessionProvider.notifier).clear();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong while exporting. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    final text = Theme.of(context).textTheme;
    final pages = session?.pages ?? const [];
    final pageCount = pages.length;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: scanMeAppBarLeading(context),
          title: const Text('Export as image'),
        ),
        body: session == null
            ? const AppEmptyState(
                title: 'Nothing to export',
                subtitle: 'Go back and capture or import pages first.',
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        Text(
                          session.name,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose which pages to save as JPG on this phone.',
                          style: text.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Pages to save',
                                style: text.titleSmall,
                              ),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                        _selectedPages = {
                                          for (var i = 0; i < pageCount; i++)
                                            i,
                                        };
                                      }),
                              child: const Text('All'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _selectedPages = {}),
                              child: const Text('None'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_selectedPages.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              '${_selectedPages.length} of $pageCount selected',
                              style: text.labelMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pageCount,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemBuilder: (context, i) {
                            final page = pages[i];
                            final selected = _selectedPages.contains(i);
                            final path = page.displayPath;
                            final hasImage =
                                path.isNotEmpty && File(path).existsSync();
                            return _ExportPageTile(
                              index: i,
                              selected: selected,
                              enabled: !_busy,
                              imagePath: hasImage ? path : null,
                              rotation: page.rotation,
                              onTap: () {
                                setState(() {
                                  final next = {..._selectedPages};
                                  if (selected) {
                                    next.remove(i);
                                  } else {
                                    next.add(i);
                                  }
                                  _selectedPages = next;
                                });
                              },
                            );
                          },
                        ),
                        if (_progress != null) ...[
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: AppMotion.medium,
                            child: AppProgressCard(
                              key: ValueKey(_progress),
                              title: 'Saving images',
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
                          onPressed:
                              _busy || _selectedPages.isEmpty ? null : _save,
                          icon: Icon(
                            _busy ? Icons.hourglass_top : Icons.save_alt,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                          ),
                          label: Text(_busy ? 'Saving…' : 'Save images'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ExportPageTile extends StatelessWidget {
  const _ExportPageTile({
    required this.index,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.imagePath,
    this.rotation = 0,
  });

  final int index;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? imagePath;
  final int rotation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Page ${index + 1}',
      child: Material(
        color: scheme.surface,
        elevation: selected ? 2 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppTheme.radiusMd - 1),
                    ),
                    child: ColoredBox(
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imagePath != null)
                            RotatedBox(
                              quarterTurns: (rotation ~/ 90) % 4,
                              child: Image.file(
                                File(imagePath!),
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                                cacheWidth: 480,
                              ),
                            )
                          else
                            Center(
                              child: Icon(
                                Icons.description_outlined,
                                color: scheme.onSurfaceVariant,
                                size: 32,
                              ),
                            ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              size: 22,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Text(
                    'Page ${index + 1}',
                    textAlign: TextAlign.center,
                    style: text.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
