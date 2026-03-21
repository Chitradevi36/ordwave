import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'core/router/app_router.dart';
import 'core/storage/preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/orders/services/sync_service.dart' show SyncService, workManagerCallback;

/// Entry point — bootstraps async services then wraps the app in ProviderScope.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register background sync task (Android/iOS only — not supported on web)
  if (!kIsWeb) {
    await Workmanager().initialize(
      workManagerCallback,
      isInDebugMode: false,
    );
    await SyncService.registerPeriodicSync();
  }

  final sharedPrefs = await SharedPreferences.getInstance();
  final prefsService = PreferencesService(sharedPrefs);

  runApp(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(prefsService),
      ],
      child: const OrdWaveApp(),
    ),
  );
}

class OrdWaveApp extends ConsumerWidget {
  const OrdWaveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'OrdWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
