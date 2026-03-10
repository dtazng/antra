import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-256-GCM encryption/decryption service for optional E2E encryption.
///
/// Wire into [SyncEngine] push path when `encryptionEnabled = true`.
class EncryptionService {
  static const _keyLength = 32; // 256-bit
  static const _ivLength = 12; // 96-bit for GCM
  static const _macLength = 16; // 128-bit authentication tag
  static const _saltLength = 16;
  static const _pbkdf2Iterations = 100000;

  /// Encrypts [plaintext] with [key] using AES-256-GCM.
  ///
  /// Returns a base64-encoded string: `{iv}:{ciphertext+tag}`.
  String encrypt(String plaintext, Uint8List key) {
    final iv = _randomBytes(_ivLength);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _macLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = Uint8List(cipher.getOutputSize(input.length));
    final len = cipher.processBytes(input, 0, input.length, output, 0);
    cipher.doFinal(output, len);

    final ivB64 = base64.encode(iv);
    final cipherB64 = base64.encode(output);
    return '$ivB64:$cipherB64';
  }

  /// Decrypts a [ciphertext] string (format from [encrypt]) with [key].
  String decrypt(String ciphertext, Uint8List key) {
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw ArgumentError('Invalid ciphertext format');
    final iv = base64.decode(parts[0]);
    final data = base64.decode(parts[1]);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _macLength * 8,
          iv,
          Uint8List(0),
        ),
      );

    final output = Uint8List(cipher.getOutputSize(data.length));
    final len = cipher.processBytes(data, 0, data.length, output, 0);
    cipher.doFinal(output, len);

    return utf8.decode(output);
  }

  /// Derives a 256-bit key from [passphrase] and [salt] using PBKDF2-HMAC-SHA256.
  Uint8List deriveKey(String passphrase, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
  }

  /// Generates a random salt for key derivation.
  Uint8List generateSalt() => _randomBytes(_saltLength);

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
