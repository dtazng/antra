import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import 'package:antra/config.dart';

// ---------------------------------------------------------------------------
// Request / Response models
// ---------------------------------------------------------------------------

class SyncPullRequest {
  final String lastSyncTimestamp;
  final String? cursor;

  const SyncPullRequest({required this.lastSyncTimestamp, this.cursor});

  Map<String, dynamic> toJson() => {
        'lastSyncTimestamp': lastSyncTimestamp,
        if (cursor != null) 'cursor': cursor,
      };
}

class SyncPullResponse {
  final List<Map<String, dynamic>> records;
  final String serverTimestamp;
  final bool hasMore;
  final String? nextCursor;

  const SyncPullResponse({
    required this.records,
    required this.serverTimestamp,
    required this.hasMore,
    this.nextCursor,
  });

  factory SyncPullResponse.fromJson(Map<String, dynamic> json) =>
      SyncPullResponse(
        records: (json['records'] as List)
            .cast<Map<String, dynamic>>(),
        serverTimestamp: json['serverTimestamp'] as String,
        hasMore: json['hasMore'] as bool,
        nextCursor: json['nextCursor'] as String?,
      );
}

class SyncRecord {
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final String? syncId;

  const SyncRecord({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    this.syncId,
  });

  Map<String, dynamic> toJson() => {
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'payload': payload,
        if (syncId != null) 'syncId': syncId,
      };
}

class ConflictInfo {
  final Map<String, dynamic> clientItem;
  final Map<String, dynamic> serverItem;

  const ConflictInfo({required this.clientItem, required this.serverItem});

  factory ConflictInfo.fromJson(Map<String, dynamic> json) => ConflictInfo(
        clientItem: (json['clientItem'] as Map).cast<String, dynamic>(),
        serverItem: (json['serverItem'] as Map).cast<String, dynamic>(),
      );
}

class SyncPushRequest {
  final List<SyncRecord> records;

  const SyncPushRequest({required this.records});

  Map<String, dynamic> toJson() => {
        'records': records.map((r) => r.toJson()).toList(),
      };
}

class SyncPushResponse {
  final int appliedCount;
  final List<ConflictInfo> conflicts;
  final Map<String, String> syncIds;

  const SyncPushResponse({
    required this.appliedCount,
    required this.conflicts,
    required this.syncIds,
  });

  factory SyncPushResponse.fromJson(Map<String, dynamic> json) =>
      SyncPushResponse(
        appliedCount: json['appliedCount'] as int,
        conflicts: (json['conflicts'] as List)
            .cast<Map<String, dynamic>>()
            .map(ConflictInfo.fromJson)
            .toList(),
        syncIds: (json['syncIds'] as Map).cast<String, String>(),
      );
}

// ---------------------------------------------------------------------------
// ApiClient
// ---------------------------------------------------------------------------

class ApiClientException implements Exception {
  final int statusCode;
  final String message;

  const ApiClientException(this.statusCode, this.message);

  @override
  String toString() => 'ApiClientException($statusCode): $message';
}

class ApiClient {
  final String _baseUrl;
  final http.Client _http;

  ApiClient({String? baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl ?? AppConfig.apiGatewayBaseUrl,
        _http = httpClient ?? http.Client();

  /// Returns a Bearer token. In local-dev mode (Amplify not configured or no
  /// active session) falls back to a static dev token so the local server can
  /// accept any non-empty Authorization header.
  Future<String> _accessToken() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      final token =
          session.userPoolTokensResult.value?.accessToken.toJson();
      if (token != null) return token;
    } catch (_) {
      // Amplify not configured or session expired — use dev fallback.
    }
    return 'dev-local-token';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _accessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// POST /sync/pull
  Future<SyncPullResponse> pull(SyncPullRequest request) async {
    final uri = Uri.parse('$_baseUrl/sync/pull');
    final response = await _http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    _checkStatus(response);
    return SyncPullResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// POST /sync/push
  Future<SyncPushResponse> push(SyncPushRequest request) async {
    final uri = Uri.parse('$_baseUrl/sync/push');
    final response = await _http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(request.toJson()),
    );
    _checkStatus(response);
    return SyncPushResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiClientException(
      response.statusCode,
      response.body,
    );
  }
}
