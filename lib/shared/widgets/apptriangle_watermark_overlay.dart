import 'package:flutter/material.dart';

/// Small Apptriangle mark for live page preview (export bakes it into pixels).
class ApptriangleWatermarkOverlay extends StatelessWidget {
  const ApptriangleWatermarkOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
          child: Opacity(
            opacity: 0.55,
            child: Image.asset(
              'assets/branding/apptriangle_logo.png',
              width: 96,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
