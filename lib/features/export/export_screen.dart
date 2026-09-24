import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';
import '../document_editor/editor_controller.dart';
import 'export_image_screen.dart';
import 'export_pdf_ready_screen.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late final TextEditingController _nameController;
  bool _busy = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    final session = ref.read(editorSessionProvider);
    _nameController = TextEditingController(
      text: session?.name ?? 'Scanned document',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  ExportSettings _pdfSettings() {
    final session = ref.read(editorSessionProvider);
    return ExportSettings(
      createPdf: true,
      saveImages: false,
      alsoSaveToDevice: false,
      currentPageIndex: session?.selectedIndex ?? 0,
      imageScope: ImageExportScope.selectedPages,
      selectedPageIndexes: const {},
      imageFormat: ImageExportFormat.jpg,
      imageQuality: ImageExportQuality.high,
    );
  }

  Future<void> _backToHome() async {
    if (_busy) return;
    final ok = await showConfirmSheet(
      context: context,
      title: 'Leave without saving?',
      message:
          'This discards the scan and returns to Home. You cannot undo this.',
      confirmLabel: 'Discard & go Home',
      cancelLabel: 'Stay',
      destructive: true,
      icon: Icons.home_outlined,
    );
    if (ok != true || !mounted) return;
    await ref.read(editorSessionProvider.notifier).discardUnsaved();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openImageExport() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a document name.')),
      );
      return;
    }
    ref.read(editorSessionProvider.notifier).setName(name);
    AppPageRoute.push(context, const ExportImageScreen());
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: scanMeAppBarLeading(context),
          title: const Text('Export'),
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
                        Text('Export as', style: text.titleSmall),
                        const SizedBox(height: 10),
                        _DotOption(
                          selected: false,
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'Export as PDF',
                          subtitle: 'Open viewer · share or download',
                          enabled: !_busy,
                          onTap: _exportPdf,
                        ),
                        const SizedBox(height: 10),
                        _DotOption(
                          selected: false,
                          icon: Icons.image_outlined,
                          title: 'Export as image',
                          subtitle: 'Pick pages · save JPG to phone',
                          enabled: !_busy,
                          trailing: Icons.chevron_right,
                          onTap: _openImageExport,
                        ),
                        if (_progress != null) ...[
                          const SizedBox(height: 28),
                          AnimatedSwitcher(
                            duration: AppMotion.medium,
                            child: AppProgressCard(
                              key: ValueKey(_progress),
                              title: 'Creating PDF',
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
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : _backToHome,
                          icon: const Icon(Icons.home_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(color: scheme.error),
                            minimumSize: const Size(48, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                          ),
                          label: const Text('Back to Home'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a document name.')),
      );
      return;
    }
    setState(() {
      _busy = true;
      _progress = 'Preparing…';
    });
    ref.read(editorSessionProvider.notifier).setName(name);
    try {
      final outcome = await ref.read(editorSessionProvider.notifier).export(
            settings: _pdfSettings(),
            onProgress: (label) {
              if (mounted) setState(() => _progress = label);
            },
          );
      if (!mounted) return;
      final pdfPath = outcome.doc.pdfPath;
      if (pdfPath == null || !File(pdfPath).existsSync()) {
        throw StateError('PDF missing');
      }
      ref.read(editorSessionProvider.notifier).clear();
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        AppPageRoute(
          builder: (_) => ExportPdfReadyScreen(
            path: pdfPath,
            title: outcome.doc.name,
            previewPagePaths: outcome.pdfPreviewPaths,
          ),
        ),
        (route) => route.isFirst,
      );
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
}

class _DotOption extends StatelessWidget {
  const _DotOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      onTap: enabled ? onTap : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : scheme.surface,
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: 2,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Icon(icon, color: scheme.primary, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
