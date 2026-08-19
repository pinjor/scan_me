import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/product_surface.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/library_models.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/tag_sheets.dart';
import '../home/nav_catalog.dart';
import '../onboarding/onboarding_screen.dart';
import 'theme_studio_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// When true (Me tab), title is "Me" and body pads for bottom nav.
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _trashDays = 30;
  String _versionLabel = 'Apptriangle';

  @override
  void initState() {
    super.initState();
    _loadTrashDays();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final v = info.version.trim();
      setState(() {
        _versionLabel = v.isEmpty ? 'Apptriangle' : 'Apptriangle · v$v';
      });
    } catch (_) {}
  }

  Future<void> _loadTrashDays() async {
    final days = await ref
        .read(documentStorageProvider)
        .getTrashRetentionDays();
    if (mounted) setState(() => _trashDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: scanMeAppBarLeading(context),
              title: const Text('Settings'),
            ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, widget.embedded ? 108 : 24),
          children: [
            if (widget.embedded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
                child: Text('Me', style: text.headlineSmall),
              ),
            ],
            const SectionHeader(
              title: 'Appearance',
              padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
            ),
            AppCard(
              elevated: true,
              bordered: false,
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
            const SizedBox(height: 12),
            AppCard(
              elevated: true,
              bordered: false,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.palette_outlined, color: scheme.primary),
                title: const Text('Themes'),
                subtitle: Text(ref.watch(themePresetProvider).name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    AppPageRoute.push(context, const ThemeStudioScreen()),
              ),
            ),
            if (!kScanOnlySurface) ...[
              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Navigation',
                padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
              ),
              AppCard(
                elevated: true,
                bordered: false,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.view_week_outlined,
                        color: scheme.primary,
                      ),
                      title: const Text('Left of Scan'),
                      subtitle: Text(
                        ref.watch(navSlotsProvider).innerLeft.label,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickNavSlot(left: true),
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    ListTile(
                      leading: Icon(Icons.view_week, color: scheme.primary),
                      title: const Text('Right of Scan'),
                      subtitle: Text(
                        ref.watch(navSlotsProvider).innerRight.label,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickNavSlot(left: false),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Text(
                  'Home, Scan, and Me stay put. Pick tools for the two inner slots.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'Storage',
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            ),
            AppCard(
              elevated: true,
              bordered: false,
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.auto_delete_outlined,
                  color: scheme.primary,
                ),
                title: const Text('Trash retention'),
                subtitle: Text(
                  'Recently deleted documents are kept for $_trashDays days, then removed automatically.',
                ),
                isThreeLine: true,
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
            const SectionHeader(
              title: 'Tags',
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            ),
            AppCard(
              elevated: true,
              bordered: false,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ...(ref.watch(tagsProvider).valueOrNull ?? const <TagDef>[])
                      .map(
                        (tag) => Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(tag.color),
                                radius: 12,
                              ),
                              title: Text(tag.name),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _editTag(tag),
                              onLongPress: () => _deleteTag(tag),
                            ),
                            Divider(height: 1, color: scheme.outlineVariant),
                          ],
                        ),
                      ),
                  ListTile(
                    leading: Icon(Icons.add, color: scheme.primary),
                    title: const Text('Add tag'),
                    onTap: () async {
                      await showCreateOrEditTagDialog(
                        context: context,
                        ref: ref,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(
              title: 'About',
              padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
            ),
            AppCard(
              elevated: true,
              bordered: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ScanMe', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    _versionLabel,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const PrivacyBadge(
                    label:
                        'Stored privately on this device · No account required',
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.school_outlined, color: scheme.primary),
                    title: const Text('Replay tutorial'),
                    subtitle: const Text(
                      'Feature walkthrough from first launch',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => AppPageRoute.push(
                      context,
                      const OnboardingScreen(replay: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTag(TagDef tag) async {
    await showCreateOrEditTagDialog(context: context, ref: ref, existing: tag);
  }

  Future<void> _deleteTag(TagDef tag) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete “${tag.name}”?',
      message: 'Removes this tag from Settings and from every document.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(tagsProvider.notifier).delete(tag.id);
  }

  Future<void> _pickNavSlot({required bool left}) async {
    final slots = ref.read(navSlotsProvider);
    final taken = left ? slots.innerRight : slots.innerLeft;
    final current = left ? slots.innerLeft : slots.innerRight;
    final picked = await showAppBottomSheet<NavDest>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  left ? 'Left of Scan' : 'Right of Scan',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final dest in NavDest.values)
                ListTile(
                  leading: Icon(dest.icon),
                  title: Text(dest.label),
                  enabled: dest != taken,
                  selected: dest == current,
                  trailing: dest == current
                      ? Icon(Icons.check, color: scheme.primary)
                      : dest == taken
                      ? Text(
                          'In use',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  onTap: dest == taken ? null : () => Navigator.pop(ctx, dest),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    final n = ref.read(navSlotsProvider.notifier);
    if (left) {
      await n.setInnerLeft(picked);
    } else {
      await n.setInnerRight(picked);
    }
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
