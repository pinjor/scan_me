import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/open_file_intent_bridge.dart';
import 'core/theme/app_theme.dart';
import 'features/home/main_shell_screen.dart';
import 'shared/widgets/scanme_widget_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge on all Android versions (required path for SDK 35+).
  // Do not set statusBarColor / navigationBarColor — those map to
  // Window.setStatusBarColor / setNavigationBarColor (deprecated on API 35).
  // Native enableEdgeToEdge() + theme keep bars transparent.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  ScanMeWidgetRouter.onNewScan = (_) async {};
  OpenFileIntentBridge.ensureListening();
  runApp(const ProviderScope(child: ScanMeApp()));
}

class ScanMeApp extends ConsumerWidget {
  const ScanMeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'ScanMe',
      navigatorKey: scanMeNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scaler = mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.35,
        );
        final brightness = Theme.of(context).brightness;
        final lightBars = brightness == Brightness.light;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            // Icon appearance only — avoid deprecated bar color APIs.
            statusBarIconBrightness:
                lightBars ? Brightness.dark : Brightness.light,
            statusBarBrightness:
                lightBars ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness:
                lightBars ? Brightness.dark : Brightness.light,
            systemNavigationBarContrastEnforced: false,
          ),
          child: MediaQuery(
            data: mq.copyWith(textScaler: scaler),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const MainShellScreen(),
    );
  }
}
