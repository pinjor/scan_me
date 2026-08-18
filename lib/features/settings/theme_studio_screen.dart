import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_transitions.dart';
import '../../shared/widgets/app_ui.dart';

enum _Filter { all, single, dual, triple, mine }

/// Full-page Material 3 theme picker + custom editor.
class ThemeStudioScreen extends ConsumerStatefulWidget {
  const ThemeStudioScreen({super.key});

  @override
  ConsumerState<ThemeStudioScreen> createState() => _ThemeStudioScreenState();
}

class _ThemeStudioScreenState extends ConsumerState<ThemeStudioScreen> {
  var _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(themeSelectionProvider);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final list = sel.all.where((s) {
      return switch (_filter) {
        _Filter.all => true,
        _Filter.single => s.kind == ThemeKind.single,
        _Filter.dual => s.kind == ThemeKind.dual,
        _Filter.triple => s.kind == ThemeKind.triple,
        _Filter.mine => s.custom,
      };
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: const Text('Themes'),
        actions: [
          IconButton(
            tooltip: 'Create theme',
            onPressed: () => _openEditor(newCustomDraft(), creating: true),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Single, dual, or triple tones. Material 3 builds the rest. Save your own.',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  for (final f in _Filter.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(switch (f) {
                          _Filter.all => 'All',
                          _Filter.single => 'Single',
                          _Filter.dual => 'Dual',
                          _Filter.triple => 'Triple',
                          _Filter.mine => 'Mine',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: _CreateThemeCta(
                onTap: () => _openEditor(newCustomDraft(), creating: true),
              ),
            ),
          ),
          if (list.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: AppEmptyState(
                  centered: false,
                  title: 'No themes here',
                  subtitle: 'Try another filter, or create one above.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildBuilderDelegate((context, i) {
                  final spec = list[i];
                  return _ThemeCard(
                    spec: spec,
                    selected: spec.id == sel.selectedId,
                    onTap: () => ref
                        .read(themeSelectionProvider.notifier)
                        .select(spec.id),
                    onLongPress: spec.custom
                        ? () => _customActions(spec)
                        : null,
                  );
                }, childCount: list.length),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _customActions(ThemeSpec spec) async {
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') await _openEditor(spec);
    if (action == 'delete') await _delete(spec);
  }

  Future<void> _openEditor(ThemeSpec spec, {bool creating = false}) async {
    await AppPageRoute.push(
      context,
      ThemeEditorScreen(initial: spec, creating: creating),
    );
  }

  Future<void> _delete(ThemeSpec spec) async {
    final ok = await showConfirmSheet(
      context: context,
      title: 'Delete “${spec.name}”?',
      message: 'Removes this custom theme from the device.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(themeSelectionProvider.notifier).deleteCustom(spec.id);
  }
}

class _CreateThemeCta extends StatelessWidget {
  const _CreateThemeCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      elevated: false,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.add_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create theme',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick 1–3 colors · stays on this phone',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final ThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        onTap: onTap,
        elevated: selected,
        bordered: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < spec.swatches.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: spec.swatches[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                ],
                const Spacer(),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: scheme.primary),
              ],
            ),
            const Spacer(),
            Text(
              spec.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              [
                spec.kind.label,
                spec.style.label,
                if (spec.custom) 'Custom',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({
    super.key,
    required this.initial,
    this.creating = false,
  });

  final ThemeSpec initial;
  final bool creating;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  late ThemeSpec _spec;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _spec = widget.initial.copyWith(custom: true);
    _name = TextEditingController(text: _spec.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setKind(ThemeKind kind) {
    setState(() {
      _spec = _spec.copyWith(
        kind: kind,
        clearSecondary: kind == ThemeKind.single,
        secondary: kind == ThemeKind.single
            ? null
            : (_spec.secondary ?? 0xFF2A7A86),
        clearTertiary: kind != ThemeKind.triple,
        tertiary: kind == ThemeKind.triple
            ? (_spec.tertiary ?? 0xFFC6A15B)
            : null,
      );
    });
  }

  Future<void> _pick(String which) async {
    final current = switch (which) {
      'secondary' => _spec.secondaryColor ?? const Color(0xFF2A7A86),
      'tertiary' => _spec.tertiaryColor ?? const Color(0xFFC6A15B),
      _ => _spec.primaryColor,
    };
    final picked = await showAppBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColorPickerSheet(initial: current),
    );
    if (picked == null) return;
    final argb = picked.toARGB32();
    setState(() {
      _spec = switch (which) {
        'secondary' => _spec.copyWith(secondary: argb),
        'tertiary' => _spec.copyWith(tertiary: argb),
        _ => _spec.copyWith(primary: argb),
      };
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? 'My theme' : _name.text.trim();
    await ref
        .read(themeSelectionProvider.notifier)
        .saveCustom(_spec.copyWith(name: name, custom: true));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final preview = _spec.scheme(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        leading: scanMeAppBarLeading(context),
        title: Text(widget.creating ? 'Create theme' : 'Edit theme'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (v) => _spec = _spec.copyWith(name: v),
          ),
          const SizedBox(height: 16),
          Text('Tones', style: text.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final k in ThemeKind.values)
                ChoiceChip(
                  label: Text(k.label),
                  selected: _spec.kind == k,
                  onSelected: (_) => _setKind(k),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Style', style: text.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in ThemeStyle.values)
                ChoiceChip(
                  label: Text(s.label),
                  selected: _spec.style == s,
                  onSelected: (_) => setState(() {
                    _spec = _spec.copyWith(style: s);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Colors', style: text.labelMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              _ColorWell(
                label: 'Primary',
                color: _spec.primaryColor,
                onTap: () => _pick('primary'),
              ),
              if (_spec.kind != ThemeKind.single) ...[
                const SizedBox(width: 12),
                _ColorWell(
                  label: 'Secondary',
                  color: _spec.secondaryColor ?? scheme.secondary,
                  onTap: () => _pick('secondary'),
                ),
              ],
              if (_spec.kind == ThemeKind.triple) ...[
                const SizedBox(width: 12),
                _ColorWell(
                  label: 'Tertiary',
                  color: _spec.tertiaryColor ?? scheme.tertiary,
                  onTap: () => _pick('tertiary'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text('Preview', style: text.labelMedium),
          const SizedBox(height: 8),
          AppCard(
            elevated: true,
            bordered: false,
            color: preview.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.text.trim().isEmpty ? 'My theme' : _name.text.trim(),
                  style: text.titleMedium?.copyWith(color: preview.onSurface),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: preview.primary,
                        foregroundColor: preview.onPrimary,
                      ),
                      child: const Text('Primary'),
                    ),
                    FilledButton.tonal(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: preview.secondaryContainer,
                        foregroundColor: preview.onSecondaryContainer,
                      ),
                      child: const Text('Secondary'),
                    ),
                    if (_spec.kind == ThemeKind.triple)
                      Chip(
                        label: const Text('Tertiary'),
                        backgroundColor: preview.tertiaryContainer,
                        labelStyle: TextStyle(
                          color: preview.onTertiaryContainer,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorWell extends StatelessWidget {
  const _ColorWell({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: text.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerSheet extends StatefulWidget {
  const _ColorPickerSheet({required this.initial});

  final Color initial;

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late HSVColor _hsv;

  static const _palette = <Color>[
    Color(0xFF1B3A4B),
    Color(0xFF0F6C7A),
    Color(0xFF2D6A4F),
    Color(0xFF5B8C2A),
    Color(0xFF2A9D8F),
    Color(0xFF1D6FA5),
    Color(0xFF3F51B5),
    Color(0xFF6B4C9A),
    Color(0xFF7C4DFF),
    Color(0xFFC2185B),
    Color(0xFFAD1457),
    Color(0xFFB71C1C),
    Color(0xFFE05A4F),
    Color(0xFFC45C26),
    Color(0xFFE6A817),
    Color(0xFFC6A15B),
    Color(0xFFC2A878),
    Color(0xFF6F4E37),
    Color(0xFF1F2937),
    Color(0xFF3D5A80),
    Color(0xFF4FC3F7),
    Color(0xFFE8A87C),
    Color(0xFFB85C38),
    Color(0xFF9CA3AF),
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Pick a color', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _palette)
                GestureDetector(
                  onTap: () => setState(() => _hsv = HSVColor.fromColor(c)),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _hsv.hue,
            max: 360,
            onChanged: (v) => setState(() => _hsv = _hsv.withHue(v)),
          ),
          Slider(
            value: _hsv.saturation,
            onChanged: (v) => setState(() => _hsv = _hsv.withSaturation(v)),
          ),
          Slider(
            value: _hsv.value,
            onChanged: (v) => setState(() => _hsv = _hsv.withValue(v)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, color),
            child: const Text('Use color'),
          ),
        ],
      ),
    );
  }
}
