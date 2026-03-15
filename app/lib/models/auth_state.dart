/// Sealed class representing the authentication lifecycle state.
///
/// Not persisted; reconstructed from secure storage on app launch.
sealed class AuthState {
  const AuthState();
}

/// Initial state while secure storage is being read on cold launch.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A valid session exists for [userId] / [email].
class Authenticated extends AuthState {
  final String userId;
  final String email;

  const Authenticated({required this.userId, required this.email});
}

/// No session, or session was cleared (logout / expiry).
class Unauthenticated extends AuthState {
  /// Human-readable reason, displayed as a non-alarming hint on the login screen.
  final String? reason;

  const Unauthenticated({this.reason});
}

// ---------------------------------------------------------------------------
// AuthResult — returned by login / register calls
// ---------------------------------------------------------------------------

/// Successful response from login or register.
class AuthResult {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;

  /// Seconds until access token expires.
  final int expiresIn;

  const AuthResult({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresIn: json['expires_in'] as int,
      );
}
