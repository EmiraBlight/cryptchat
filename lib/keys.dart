import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';

class KeyManager {
  static final _storage = FlutterSecureStorage();

  static String _privateKeyKey(String userId) => 'private_x25519_$userId';
  static String _publicKeyKey(String userId) => 'public_x25519_$userId';

  /// Generates X25519 keypair, stores private key securely per user, returns public key (base64)
  static Future<String> generateAndStoreKeys(String userId) async {
    final algorithm = X25519();
    final keyPair = await algorithm.newKeyPair();

    final privateBytes = await keyPair.extractPrivateKeyBytes();
    final publicBytes = (await keyPair.extractPublicKey()).bytes;

    final privateBase64 = base64Encode(privateBytes);
    final publicBase64 = base64Encode(publicBytes);

    await _storage.write(key: _privateKeyKey(userId), value: privateBase64);
    await _storage.write(key: _publicKeyKey(userId), value: publicBase64);

    print('X25519 keypair generated for user: $userId');
    return publicBase64;
  }

  /// Retrieve stored private key
  static Future<List<int>?> getPrivateKeyBytes(String userId) async {
    final privateBase64 = await _storage.read(key: _privateKeyKey(userId));
    return privateBase64 != null ? base64Decode(privateBase64) : null;
  }

  /// Retrieve stored public key
  static Future<List<int>?> getPublicKeyBytes(String userId) async {
    final publicBase64 = await _storage.read(key: _publicKeyKey(userId));
    return publicBase64 != null ? base64Decode(publicBase64) : null;
  }

  /// Check if user already has stored keys
  static Future<bool> keysExist(String userId) async {
    final priv = await _storage.read(key: _privateKeyKey(userId));
    final pub = await _storage.read(key: _publicKeyKey(userId));
    return priv != null && pub != null;
  }

  /// List all user IDs that have stored keys locally
  static Future<List<String>> listAccounts() async {
    final allKeys = await _storage.readAll();
    final userIds = <String>{};
    for (final key in allKeys.keys) {
      final match = RegExp(r'private_x25519_(.+)').firstMatch(key);
      if (match != null) userIds.add(match.group(1)!);
    }
    return userIds.toList();
  }

  /// Delete stored keys for a specific user (optional cleanup helper)
  static Future<void> deleteKeys(String userId) async {
    await _storage.delete(key: _privateKeyKey(userId));
    await _storage.delete(key: _publicKeyKey(userId));
  }
}
