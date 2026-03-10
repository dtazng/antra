import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:antra/database/app_database.dart';

part 'database_provider.g.dart';

const _kDbKeyStorageKey = 'antra_db_encryption_key';

/// Returns a hex-encoded 256-bit random key for SQLCipher.
String _generateKey() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Opens (or creates) the drift database with an AES-256 SQLCipher passphrase.
///
/// The key is generated on first launch and persisted in the platform secure
/// keystore (iOS Keychain / Android Keystore) via [flutter_secure_storage].
/// Subsequent launches read the stored key so the database can be decrypted.
@Riverpod(keepAlive: true)
Future<AppDatabase> appDatabase(AppDatabaseRef ref) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? key = await storage.read(key: _kDbKeyStorageKey);
  if (key == null) {
    key = _generateKey();
    await storage.write(key: _kDbKeyStorageKey, value: key);
  }

  // Resolve the platform-appropriate documents directory.
  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbFolder.path, 'antra.sqlite'));

  // Open SQLite on a background isolate for non-blocking UI.
  final executor = NativeDatabase.createBackgroundConnection(dbFile);

  final db = AppDatabase(executor);

  // Set SQLCipher key as the first pragma before any other statement.
  await db.customStatement("PRAGMA key = '$key'");

  ref.onDispose(db.close);
  return db;
}
