import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:antra/config.dart';
import 'package:antra/models/auth_state.dart';

// ---------------------------------------------------------------------------
// Secure storage keys
// ---------------------------------------------------------------------------

const _kAccessToken = 'auth_access_token';
const _kRefreshToken = 'auth_refresh_token';
const _kUserId = 'auth_user_id';
const _kUserEmail = 'auth_user_email';

// ---------------------------------------------------------------------------
// Typed exceptions
// ---------------------------------------------------------------------------

class AuthException implements Exception {
  final int? statusCode;
  final String message;

  const AuthException({this.statusCode, required this.message});

  @override
  String toString() => 'AuthException(${statusCode ?? '?'}): $message';
}

// ---------------------------------------------------------------------------
// AuthService
// ---------------------------------------------------------------------------

/// Handles all authentication-related HTTP calls and secure token persistence.
///
/// This is a plain Dart class (no Flutter imports) — injectable in tests.
class AuthService {
  final String _baseUrl;
  final http.Client _http;
  final FlutterSecureStorage _storage;

  AuthService({
    String? baseUrl,
    http.Client? httpClient,
    FlutterSecureStorage? storage,
  })  : _baseUrl = baseUrl ?? AppConfig.apiGatewayBaseUrl,
        _http = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns the stored access token, or null if not authenticated.
  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);

  /// Returns the stored refresh token, or null.
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  /// Returns the cached user ID, or null.
  Future<String?> getUserId() => _storage.read(key: _kUserId);

  /// Returns the cached email, or null.
  Future<String?> getUserEmail() => _storage.read(key: _kUserEmail);

  /// Reconstructs an [Authenticated] state from storage, or null if no tokens.
  Future<AuthState?> loadSession() async {
    final token = await getAccessToken();
    if (token == null) return null;
    final userId = await getUserId();
    final email = await getUserEmail();
    if (userId == null || email == null) return null;
    return Authenticated(userId: userId, email: email);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> _persistResult(AuthResult result) async {
    await Future.wait([
      _storage.write(key: _kAccessToken, value: result.accessToken),
      _storage.write(key: _kRefreshToken, value: result.refreshToken),
      _storage.write(key: _kUserId, value: result.userId),
      _storage.write(key: _kUserEmail, value: result.email),
    ]);
  }

  /// Clears all auth tokens from secure storage.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserEmail),
    ]);
  }

  // ── Auth endpoints ────────────────────────────────────────────────────────

  /// Registers a new account and persists the resulting session.
  Future<AuthResult> register(String email, String password) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _assertSuccess(response);
    final result = AuthResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _persistResult(result);
    return result;
  }

  /// Logs in and persists the resulting session.
  Future<AuthResult> login(String email, String password) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    _assertSuccess(response);
    final result = AuthResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _persistResult(result);
    return result;
  }

  /// Attempts to refresh the access token using the stored refresh token.
  ///
  /// Returns `true` on success (new tokens persisted), `false` on failure.
  Future<bool> tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await _http.post(
        Uri.parse('$_baseUrl/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      await Future.wait([
        _storage.write(
            key: _kAccessToken, value: body['access_token'] as String),
        _storage.write(
            key: _kRefreshToken, value: body['refresh_token'] as String),
      ]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Logs out by calling the backend and clearing local session.
  Future<void> logout() async {
    final refreshToken = await getRefreshToken();
    final accessToken = await getAccessToken();
    if (refreshToken != null && accessToken != null) {
      try {
        await _http.post(
          Uri.parse('$_baseUrl/v1/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      } catch (_) {
        // Best-effort — always clear local session regardless.
      }
    }
    await clearSession();
  }

  /// Changes the user's password.
  ///
  /// Throws [AuthException] with status 401 if [currentPassword] is wrong,
  /// or status 422 if [newPassword] is too short.
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final accessToken = await getAccessToken();
    final response = await _http.post(
      Uri.parse('$_baseUrl/v1/auth/change-password'),
      headers: {
        'Content-Type': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );
    _assertSuccess(response);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _assertSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String message;
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = body['message'] as String? ?? response.body;
    } catch (_) {
      message = response.body;
    }
    throw AuthException(statusCode: response.statusCode, message: message);
  }
}
