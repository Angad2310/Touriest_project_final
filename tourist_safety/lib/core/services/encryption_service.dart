import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

/// AES-256-GCM encryption service for distress payloads.
///
/// Key management:
/// - A 256-bit random key is generated on first run and stored in
///   `flutter_secure_storage` (hardware-backed Keystore on Android,
///   Keychain on iOS).
/// - Same key for the install lifetime. Uninstalling the app wipes the key.
///
/// Usage:
///   final svc = ref.read(encryptionServiceProvider);
///   final encrypted = await svc.encryptJson(payload.toJson());
///   final json     = await svc.decryptJson(encrypted);
class EncryptionService {
  static const _keyStorageKey = 'tourist_safety_aes_key';
  static const _keyLength = 32; // 256 bits

  final FlutterSecureStorage _storage;
  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Key? _cachedKey;

  EncryptionService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  // ─── Public API ────────────────────────────────────────────

  /// Encrypt a JSON map. Returns a compact string: `base64(iv).base64(cipher)`
  Future<String> encryptJson(Map<String, dynamic> json) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final iv = IV.fromSecureRandom(16);
    final plaintext = jsonEncode(json);
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}.${encrypted.base64}';
  }

  /// Decrypt a payload encrypted by [encryptJson].
  Future<Map<String, dynamic>> decryptJson(String encryptedPayload) async {
    final parts = encryptedPayload.split('.');
    if (parts.length != 2) {
      throw const FormatException('Invalid encrypted payload: expected iv.ciphertext');
    }
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final iv = IV.fromBase64(parts[0]);
    final ciphertext = Encrypted.fromBase64(parts[1]);
    final plaintext = encrypter.decrypt(ciphertext, iv: iv);
    return jsonDecode(plaintext) as Map<String, dynamic>;
  }

  /// Encrypt raw bytes (reserved for audio snippets in Phase 2).
  Future<EncryptedBytes> encryptBytes(Uint8List bytes) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final iv = IV.fromSecureRandom(16);
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);
    return EncryptedBytes(iv: iv.bytes, ciphertext: encrypted.bytes);
  }

  /// Decrypt raw bytes encrypted by [encryptBytes].
  Future<Uint8List> decryptBytes(EncryptedBytes eb) async {
    final key = await _getOrCreateKey();
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final iv = IV(eb.iv);
    final encrypted = Encrypted(eb.ciphertext);
    final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
    return Uint8List.fromList(decrypted);
  }

  /// Wipe the stored key (call on logout / account deletion).
  Future<void> wipeKey() async {
    await _storage.delete(key: _keyStorageKey);
    _cachedKey = null;
    _log.i('Encryption key wiped');
  }

  // ─── Internal ─────────────────────────────────────────────

  Future<Key> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final stored = await _storage.read(key: _keyStorageKey);
    if (stored != null) {
      _cachedKey = Key.fromBase64(stored);
      return _cachedKey!;
    }

    // Generate a cryptographically-secure 256-bit key
    final rng = Random.secure();
    final rawKey = Uint8List.fromList(
      List.generate(_keyLength, (_) => rng.nextInt(256)),
    );
    final key = Key(rawKey);
    await _storage.write(key: _keyStorageKey, value: key.base64);
    _cachedKey = key;
    _log.i('New AES-256-GCM key generated and stored in secure storage');
    return key;
  }
}

/// Wrapper for encrypted raw bytes (IV + ciphertext kept together).
class EncryptedBytes {
  final Uint8List iv;
  final Uint8List ciphertext;
  const EncryptedBytes({required this.iv, required this.ciphertext});
}

/// Riverpod provider for EncryptionService.
final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});
