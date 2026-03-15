import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:antra/models/user_settings.dart';

/// Fetches and updates user settings from the Go backend.
class UserSettingsService {
  final String _baseUrl;
  final http.Client _http;

  /// [accessTokenFn] is called before each request to get the current Bearer token.
  final Future<String?> Function() _accessTokenFn;

  UserSettingsService({
    required String baseUrl,
    required http.Client httpClient,
    required Future<String?> Function() accessTokenFn,
  })  : _baseUrl = baseUrl,
        _http = httpClient,
        _accessTokenFn = accessTokenFn;

  Future<Map<String, String>> _headers() async {
    final token = await _accessTokenFn();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches the current user settings from `GET /v1/settings`.
  Future<UserSettings> getSettings() async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/v1/settings'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to load settings (${response.statusCode}): ${response.body}');
    }
    return UserSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Applies a partial update via `PATCH /v1/settings`.
  Future<UserSettings> updateSettings(UserSettingsPatch patch) async {
    final response = await _http.patch(
      Uri.parse('$_baseUrl/v1/settings'),
      headers: await _headers(),
      body: jsonEncode(patch.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception(
          'Failed to update settings (${response.statusCode}): ${response.body}');
    }
    return UserSettings.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
