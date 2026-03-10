import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'package:antra/providers/database_provider.dart';
import 'package:antra/providers/sync_status_provider.dart';
import 'package:antra/screens/root_tab_screen.dart';
import 'package:antra/services/api_client.dart';
import 'package:antra/services/sync_engine.dart';

const _backgroundSyncTask = 'antra.background_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _backgroundSyncTask) {
      final container = ProviderContainer();
      try {
        final db = await container.read(appDatabaseProvider.future);
        final engine = SyncEngine(db: db, apiClient: ApiClient());
        await engine.sync();
      } finally {
        container.dispose();
      }
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final flnPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await flnPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'antra-periodic-sync',
      _backgroundSyncTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
    );
  } catch (_) {
    // Workmanager not available on this platform/build — skip.
  }

  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    // await Amplify.configure(amplifyconfig); // uncomment after amplify pull
  } on AmplifyAlreadyConfiguredException {
    // hot-restart
  } catch (_) {
    // Amplify not configured — local-only mode.
  }

  runApp(const ProviderScope(child: AntraApp()));
}

ThemeData _buildTheme(Brightness brightness) {
  const seed = Color(0xFF5B6AF5);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: seed, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withOpacity(0.4)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.primary,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        );
      }),
    ),
  );
}

class AntraApp extends StatelessWidget {
  const AntraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antra',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const _SyncObserver(child: RootTabScreen()),
    );
  }
}

class _SyncObserver extends ConsumerStatefulWidget {
  final Widget child;

  const _SyncObserver({required this.child});

  @override
  ConsumerState<_SyncObserver> createState() => _SyncObserverState();
}

class _SyncObserverState extends ConsumerState<_SyncObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncStatusNotifierProvider.notifier).triggerSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncStatusNotifierProvider.notifier).triggerSync();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
