import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_ui.dart';

/// Offline QR / barcode reader (camera + photo).
class QrReaderScreen extends StatefulWidget {
  const QrReaderScreen({super.key});

  @override
  State<QrReaderScreen> createState() => _QrReaderScreenState();
}

class _QrReaderScreenState extends State<QrReaderScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.aztec,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  var _handling = false;
  String? _lastRaw;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;
    if (raw == _lastRaw) return;

    _handling = true;
    _lastRaw = raw;
    await _controller.stop();
    if (!mounted) return;
    await _showResult(raw);
    if (!mounted) return;
    _handling = false;
    _lastRaw = null;
    await _controller.start();
  }

  Future<void> _scanFromGallery() async {
    if (_handling) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;

    _handling = true;
    try {
      await _controller.stop();
      final capture = await _controller.analyzeImage(file.path);
      final raw = capture?.barcodes.firstOrNull?.rawValue?.trim();
      if (!mounted) return;
      if (raw == null || raw.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No code found in that photo.')),
        );
      } else {
        await _showResult(raw);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read that photo.')),
        );
      }
    } finally {
      _handling = false;
      if (mounted) await _controller.start();
    }
  }

  Future<void> _showResult(String raw) async {
    final isUrl = _looksLikeUrl(raw);
    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final text = Theme.of(ctx).textTheme;
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Code found', style: text.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppCard(
                elevated: false,
                padding: const EdgeInsets.all(14),
                child: SelectableText(
                  raw,
                  style: text.bodyLarge?.copyWith(height: 1.35),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Processed on this device',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (isUrl) ...[
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _openUrl(raw);
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open link'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: raw));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 52),
                  ),
                ),
              ] else
                FilledButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: raw));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 52),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await SharePlus.instance.share(ShareParams(text: raw));
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Scan again'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String raw) async {
    var s = raw.trim();
    if (s.toLowerCase().startsWith('www.')) s = 'https://$s';
    final uri = Uri.tryParse(s);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  bool _looksLikeUrl(String raw) {
    final lower = raw.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.scannerBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scannerBg,
        foregroundColor: Colors.white,
        leading: scanMeAppBarLeading(context, color: Colors.white),
        title: Text(
          'QR reader',
          style: text.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Torch off' : 'Torch on',
                onPressed: () => _controller.toggleTorch(),
                icon: Icon(on ? Icons.flash_on : Icons.flash_off_outlined),
              );
            },
          ),
          IconButton(
            tooltip: 'Scan from photo',
            onPressed: _scanFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return ColoredBox(
                color: AppTheme.scannerBg,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    brightness: Brightness.dark,
                    colorScheme: ColorScheme.fromSeed(
                      seedColor: AppTheme.accent,
                      brightness: Brightness.dark,
                    ),
                  ),
                  child: AppEmptyState(
                    title: 'Camera unavailable',
                    subtitle:
                        'Allow camera access in settings, then try again.',
                    primaryLabel: 'Go back',
                    primaryIcon: Icons.arrow_back,
                    onPrimary: () => Navigator.of(context).pop(),
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: _QrFramePainter(),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Point at a QR code or barcode',
                      style: text.titleSmall?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stays on this device',
                      style: text.bodySmall?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: size.width * 0.7,
        height: size.width * 0.7,
      ),
      const Radius.circular(20),
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final r = hole.outerRect;
    const len = 28.0;
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(len, 0), stroke);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, len), stroke);
    canvas.drawLine(r.topRight, r.topRight + const Offset(-len, 0), stroke);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, len), stroke);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(len, 0), stroke);
    canvas.drawLine(r.bottomLeft, r.bottomLeft + const Offset(0, -len), stroke);
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + const Offset(-len, 0),
      stroke,
    );
    canvas.drawLine(
      r.bottomRight,
      r.bottomRight + const Offset(0, -len),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
