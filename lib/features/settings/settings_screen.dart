import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _trashDays = 30;

  @override
  void initState() {
    super.initState();
    _loadTrashDays();
  }

  Future<void> _loadTrashDays() async {
    final days =
        await ref.read(documentStorageProvider).getTrashRetentionDays();
    if (mounted) setState(() => _trashDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              'Appearance',
              style: text.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          AppCard(
            elevated: false,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ThemeOption(
                  icon: Icons.phone_android_outlined,
                  title: 'System',
                  selected: mode == ThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.system),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _ThemeOption(
                  icon: Icons.light_mode_outlined,
                  title: 'Light',
                  selected: mode == ThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.light),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _ThemeOption(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setMode(ThemeMode.dark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Trash',
              style: text.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          AppCard(
            elevated: false,
            padding: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              leading:
                  Icon(Icons.auto_delete_outlined, color: scheme.primary),
              title: const Text('Auto-delete'),
              subtitle: Text('After $_trashDays days'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDialog<int>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: const Text('Keep trash for'),
                    children: [
                      for (final d in [7, 14, 30, 60, 90])
                        SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, d),
                          child: Text('$d days'),
                        ),
                    ],
                  ),
                );
                if (picked != null) {
                  await ref
                      .read(documentStorageProvider)
                      .setTrashRetentionDays(picked);
                  if (mounted) setState(() => _trashDays = picked);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'About',
              style: text.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          AppCard(
            elevated: false,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ScanMe', style: text.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Apptriangle · v1.0.0',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: text.titleMedium)),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
