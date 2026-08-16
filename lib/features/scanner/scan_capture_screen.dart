import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';
import '../../shared/widgets/app_transitions.dart';
import '../document_editor/editor_controller.dart';
import '../document_editor/review_screen.dart';
import '../../core/providers.dart';
import 'document_scanner_service.dart';

/// Multi-page scan hub. ML Kit captures one page; Add Page / Continue live here.
class ScanCaptureScreen extends ConsumerStatefulWidget {
  const ScanCaptureScreen({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  ConsumerState<ScanCaptureScreen> createState() => _ScanCaptureScreenState();
}

class _ScanCaptureScreenState extends ConsumerState<ScanCaptureScreen> {
  var _busy = false;
  var _didAutoStart = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didAutoStart) return;
        _didAutoStart = true;
        final session = ref.read(editorSessionProvider);
        if (session == null || session.pages.isEmpty) {
          _addPage(isFirst: true);
        }
      });
    }
  }

  Future<void> _addPage({bool isFirst = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final outcome =
          await ref.read(documentScannerProvider).scan(pageLimit: 1);
      if (!mounted) return;

      switch (outcome) {
        case ScanCancelled():
          if (isFirst &&
              (ref.read(editorSessionProvider)?.pages.isEmpty ?? true)) {
            Navigator.of(context).pop();
          }
          return;
        case ScanError(:final message):
          messenger.showSnackBar(SnackBar(content: Text(message)));
          if (isFirst &&
              (ref.read(editorSessionProvider)?.pages.isEmpty ?? true)) {
            Navigator.of(context).pop();
          }
          return;
        case ScanSuccess(:final imagePaths):
          if (imagePaths.isEmpty) return;
          if (isFirst || ref.read(editorSessionProvider) == null) {
            await ref
                .read(editorSessionProvider.notifier)
                .startFromScanPaths(imagePaths);
          } else {
            await ref
                .read(editorSessionProvider.notifier)
                .appendPagesFromScanPaths(imagePaths);
          }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not import page: $e')),
        );
      }
      if (isFirst && mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goNext() {
    final session = ref.read(editorSessionProvider);
    if (session == null || session.pages.isEmpty) return;
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const ReviewScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(editorSessionProvider);
    final pages = session?.pages ?? const [];
    final selected = session?.selectedPage;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final filtering = session?.isProcessing ?? false;
    final blockUi = _busy || filtering;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          ref.read(editorSessionProvider.notifier).discardUnsaved();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.scannerBg,
        appBar: AppBar(
          backgroundColor: AppTheme.scannerBg,
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scanning',
                style: text.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (pages.isNotEmpty)
                Text(
                  'Page ${(session?.selectedIndex ?? 0) + 1} of ${pages.length}',
                  style: text.bodySmall?.copyWith(color: Colors.white70),
                ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: selected == null
                      ? Center(
                          child: Text(
                            _busy ? 'Opening camera…' : 'No pages yet',
                            style: text.bodyLarge?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                              child: ColoredBox(
                                color: Colors.black,
                                child: RotatedBox(
                                  quarterTurns:
                                      (selected.rotation ~/ 90) % 4,
                                  child: AnimatedSwitcher(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Image.file(
                                      File(selected.displayPath),
                                      key: ValueKey(selected.displayPath),
                                      fit: BoxFit.contain,
                                      width: double.infinity,
                                      height: double.infinity,
                                      // Downsample for display (~xxhdpi phone width).
                                      cacheWidth: 1080,
                                      filterQuality: FilterQuality.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                if (pages.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: pages.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        final isSelected = index == session!.selectedIndex;
                        return GestureDetector(
                          onTap: () => ref
                              .read(editorSessionProvider.notifier)
                              .selectPage(index),
                          child: AnimatedScale(
                            scale: isSelected ? 1.06 : 1.0,
                            duration: const Duration(milliseconds: 180),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? scheme.primary
                                      : Colors.white24,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: scheme.primary
                                              .withValues(alpha: 0.45),
                                          blurRadius: 10,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(page.displayPath),
                                  fit: BoxFit.cover,
                                  cacheWidth: 120,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141A22),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusXl),
                      ),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: blockUi
                                ? null
                                : () => _addPage(isFirst: pages.isEmpty),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white38,
                              side: const BorderSide(color: Colors.white38),
                              minimumSize: const Size(48, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Page'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                blockUi || pages.isEmpty ? null : _goNext,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                              ),
                            ),
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (blockUi)
              LoadingOverlay(
                message: filtering
                    ? (session?.processingLabel ?? 'Enhancing document…')
                    : 'Opening camera…',
              ),
          ],
        ),
      ),
    );
  }
}
