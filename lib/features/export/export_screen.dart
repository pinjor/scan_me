import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          ? const Center(child: Text('No document'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Text('Name', style: text.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Lease agreement',
                  ),
                  onChanged: (v) =>
                      ref.read(editorSessionProvider.notifier).setName(v),
                ),
                const SizedBox(height: 28),
                Text('Format', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '${session.pages.length} '
                  '${session.pages.length == 1 ? 'page' : 'pages'} · '
                  'files are compressed for sharing without muddy text.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                _FormatTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'PDF',
                  subtitle: 'One file, easy to email or print',
                  value: _createPdf,
                  enabled: !_busy,
                  onChanged: (v) => setState(() => _createPdf = v),
                ),
                const SizedBox(height: 8),
                _FormatTile(
                  icon: Icons.photo_library_outlined,
                  title: 'JPEG images',
                  subtitle: 'Separate pages (Name_01.jpg…)',
                  value: _saveImages,
                  enabled: !_busy,
                  onChanged: (v) => setState(() => _saveImages = v),
                ),
                const SizedBox(height: 32),
                if (_progress != null) ...[
                  Text(
                    _progress!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                  const SizedBox(height: 24),
                ],
                FilledButton(
                  onPressed: _busy || (!_createPdf && !_saveImages)
                      ? null
                      : _export,
                  child: Text(_busy ? 'Saving…' : 'Save on this device'),
                ),
              ],
            ),
    );
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _progress = 'Preparing…';
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
      // Pop first so Review's PopScope discard sees saved meta.json (no-op delete).
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

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: value ? scheme.primary.withValues(alpha: 0.45) : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: enabled ? () => onChanged(!value) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(icon, color: scheme.primary, size: 26),
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
        ),
      ),
    );
  }
}
