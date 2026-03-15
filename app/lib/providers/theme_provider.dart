import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

const _kThemeMode = 'app_theme_mode';

@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  static const _storage = FlutterSecureStorage();

  @override
  Future<ThemeMode> build() async {
    final raw = await _storage.read(key: _kThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setTheme(ThemeMode mode) async {
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.write(key: _kThemeMode, value: raw);
    state = AsyncValue.data(mode);
  }
}
