import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/config.dart';
import 'package:antra/models/user_settings.dart';
import 'package:antra/providers/auth_provider.dart';
import 'package:antra/services/user_settings_service.dart';

part 'user_settings_provider.g.dart';

// ---------------------------------------------------------------------------
// UserSettingsNotifier
// ---------------------------------------------------------------------------

/// Fetches and caches user settings from the backend.
///
/// On build, calls `GET /v1/settings`. Exposes [update] to apply partial
/// patches via `PATCH /v1/settings`.
@riverpod
class UserSettingsNotifier extends _$UserSettingsNotifier {
  @override
  Future<UserSettings> build() async {
    final svc = _buildService();
    return svc.getSettings();
  }

  UserSettingsService _buildService() {
    final authSvc = ref.read(authServiceProvider);
    return UserSettingsService(
      baseUrl: AppConfig.apiGatewayBaseUrl,
      httpClient: http.Client(),
      accessTokenFn: authSvc.getAccessToken,
    );
  }

  /// Applies a partial update and refreshes local state.
  Future<void> applyPatch(UserSettingsPatch patch) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic update
    state = AsyncValue.data(current.copyWith(
      notificationsEnabled: patch.notificationsEnabled,
      followUpRemindersEnabled: patch.followUpRemindersEnabled,
      defaultFollowUpDays: patch.defaultFollowUpDays,
    ));

    try {
      final updated = await _buildService().updateSettings(patch);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      // Roll back on failure
      state = AsyncValue.data(current);
      Error.throwWithStackTrace(e, st);
    }
  }
}
