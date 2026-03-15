import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/models/auth_state.dart';
import 'package:antra/services/auth_service.dart';

part 'auth_provider.g.dart';

// ---------------------------------------------------------------------------
// Shared AuthService instance
// ---------------------------------------------------------------------------

@riverpod
AuthService authService(AuthServiceRef ref) => AuthService();

// ---------------------------------------------------------------------------
// AuthNotifier
// ---------------------------------------------------------------------------

/// Manages the application's authentication state.
///
/// On build, checks secure storage for a valid session and emits either
/// [Authenticated] or [Unauthenticated]. Exposes [login], [register],
/// [logout], and [signalSessionExpired] for UI and interceptor use.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState> build() async {
    final svc = ref.read(authServiceProvider);
    final session = await svc.loadSession();
    return session ?? const Unauthenticated();
  }

  AuthService get _svc => ref.read(authServiceProvider);

  /// Logs in and transitions to [Authenticated] on success.
  ///
  /// Throws [AuthException] on failure so the UI can show an error.
  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final result = await _svc.login(email, password);
      state = AsyncValue.data(
          Authenticated(userId: result.userId, email: result.email));
    } on AuthException {
      state = const AsyncValue.data(Unauthenticated());
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Registers and transitions to [Authenticated] on success.
  Future<void> register(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final result = await _svc.register(email, password);
      state = AsyncValue.data(
          Authenticated(userId: result.userId, email: result.email));
    } on AuthException {
      state = const AsyncValue.data(Unauthenticated());
      rethrow;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Logs out and transitions to [Unauthenticated].
  Future<void> logout() async {
    await _svc.logout();
    state = const AsyncValue.data(Unauthenticated());
  }

  /// Called by [AuthHttpClient] when a refresh cycle fails.
  ///
  /// Transitions to [Unauthenticated] with a session-expired hint.
  Future<void> signalSessionExpired() async {
    await _svc.clearSession();
    state = const AsyncValue.data(
        Unauthenticated(reason: 'Your session has expired. Please log in again.'));
  }
}
