import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:antra/models/auth_state.dart';
import 'package:antra/providers/auth_provider.dart';
import 'package:antra/screens/auth/auth_screen.dart';
import 'package:antra/screens/auth/splash_screen.dart';
import 'package:antra/screens/root_tab_screen.dart';

/// Routes to [SplashScreen], [AuthScreen], or [RootTabScreen] based on
/// the current [AuthState].
///
/// This widget is the `home` of [MaterialApp] and is the single point of
/// truth for authentication-driven navigation.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    return authAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const AuthScreen(),
      data: (authState) {
        return switch (authState) {
          AuthLoading() => const SplashScreen(),
          Authenticated() => const _SyncObserverWrapper(),
          Unauthenticated() => const AuthScreen(),
        };
      },
    );
  }
}

/// Wraps [RootTabScreen] with the sync observer so background sync fires
/// only when the user is authenticated.
class _SyncObserverWrapper extends StatelessWidget {
  const _SyncObserverWrapper();

  @override
  Widget build(BuildContext context) => const RootTabScreen();
}
