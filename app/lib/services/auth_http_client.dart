import 'package:http/http.dart' as http;

import 'package:antra/services/auth_service.dart';

/// An [http.BaseClient] that transparently attaches Bearer tokens to every
/// request and handles 401 responses with a one-shot token refresh.
///
/// On refresh failure, [onAuthFailure] is called (typically to signal the
/// auth provider to transition to [Unauthenticated]).
class AuthHttpClient extends http.BaseClient {
  final http.Client _inner;
  final AuthService _authService;
  final Future<void> Function() onAuthFailure;

  AuthHttpClient({
    required http.Client inner,
    required AuthService authService,
    required this.onAuthFailure,
  })  : _inner = inner,
        _authService = authService;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _authService.getAccessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final response = await _inner.send(request);

    if (response.statusCode == 401) {
      final refreshed = await _authService.tryRefresh();
      if (refreshed) {
        final newToken = await _authService.getAccessToken();
        final retry = _copyRequest(request, newToken);
        return _inner.send(retry);
      } else {
        await _authService.clearSession();
        await onAuthFailure();
      }
    }

    return response;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }

  /// Clones a [BaseRequest] with an updated Authorization header.
  http.BaseRequest _copyRequest(http.BaseRequest original, String? newToken) {
    final copy = http.Request(original.method, original.url);
    copy.headers.addAll(original.headers);
    if (newToken != null) {
      copy.headers['Authorization'] = 'Bearer $newToken';
    }
    if (original is http.Request) {
      copy.body = original.body;
      copy.encoding = original.encoding;
    }
    return copy;
  }
}
