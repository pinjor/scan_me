import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../document_editor/editor_controller.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late final TextEditingController _nameController;
  bool _createPdf = true;
  bool _saveImages = false;
  bool _busy = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    final name = ref.read(editorSessionProvider)?.name ?? 'Scan';
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

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
                      Text('Document name', style: text.titleSmall),
                      const SizedBox(height: 10),
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
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
                            hintText: 'e.g. Invoice March 2026',
                          ),
                          style: text.titleLarge,
                          onChanged: (v) => ref
                              .read(editorSessionProvider.notifier)
                              .setName(v),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('Format', style: text.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        '${session.pages.length} '
                        '${session.pages.length == 1 ? 'page' : 'pages'} · '
                        'Compressed for sharing · Apptriangle watermark',
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FormatTile(
                        icon: Icons.picture_as_pdf_outlined,
                        title: 'PDF',
                        subtitle: 'One file — easy to email or print',
                        value: _createPdf,
                        enabled: !_busy,
                        onChanged: (v) => setState(() => _createPdf = v),
                      ),
                      const SizedBox(height: 10),
                      _FormatTile(
                        icon: Icons.photo_library_outlined,
                        title: 'JPEG images',
                        subtitle: 'Separate pages (Name_01.jpg…)',
                        value: _saveImages,
                        enabled: !_busy,
                        onChanged: (v) => setState(() => _saveImages = v),
                      ),
                      if (_progress != null) ...[
                        const SizedBox(height: 28),
                        AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(strokeWidth: 3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _progress!,
                                textAlign: TextAlign.center,
                                style: text.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Saving on this device only',
                                style: text.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const LinearProgressIndicator(minHeight: 3),
                            ],
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
                        onPressed: _busy || (!_createPdf && !_saveImages)
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
                          _busy ? 'Saving…' : 'Save on this device',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _progress = 'Preparing pages…';
    });
    ref.read(editorSessionProvider.notifier).setName(_nameController.text);
    try {
      await ref.read(editorSessionProvider.notifier).export(
            createPdf: _createPdf,
            saveImages: _saveImages,
            onProgress: (label) {
              if (mounted) setState(() => _progress = label);
            },
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved on this device')),
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
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return AppCard(
      onTap: enabled ? () => onChanged(!value) : null,
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      color: value
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surface,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(icon, color: scheme.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: text.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}
