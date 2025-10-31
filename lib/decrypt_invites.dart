import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class InviteDecryptor {
  static final _storage = FlutterSecureStorage();

  /// Decrypts an invite encrypted with X25519 + AES-GCM
  /// serverPubKeyBase64: ephemeral server public key from Rust
  /// ciphertextBase64: Rust AES-GCM ciphertext (includes 16-byte tag)
  /// nonceBase64: 12-byte nonce used in Rust
  static Future<String> decryptInvite({
    required String privateKeyUserId,
    required String serverPubKeyBase64,
    required String ciphertextBase64,
    required String nonceBase64,
  }) async {
    // --- Load user's private key from secure storage ---
    final privB64 = privateKeyUserId;

    // --- Decode base64 inputs ---
    final privBytes = base64Decode(privB64.trim());
    final serverPubBytes = base64Decode(serverPubKeyBase64.trim());
    final cipherBytes = base64Decode(ciphertextBase64.trim());
    final nonceBytes = base64Decode(nonceBase64.trim());

    if (cipherBytes.length < 16) {
      throw Exception('Ciphertext too short to contain AES-GCM tag');
    }

    // --- Split ciphertext and GCM tag (last 16 bytes) ---
    final encryptedBytes = cipherBytes.sublist(0, cipherBytes.length - 16);
    final macBytes = cipherBytes.sublist(cipherBytes.length - 16);

    final secretBox = SecretBox(
      encryptedBytes,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    // --- Construct X25519 key objects ---
    final userKeyPair = SimpleKeyPairData(
      privBytes,
      publicKey: SimplePublicKey(
        Uint8List(32), // dummy; not used in sharedSecretKey
        type: KeyPairType.x25519,
      ),
      type: KeyPairType.x25519,
    );
    final serverPublicKey = SimplePublicKey(
      serverPubBytes,
      type: KeyPairType.x25519,
    );

    // --- Derive shared secret key via Diffie-Hellman ---
    final algorithm = X25519();
    final sharedSecretKey = await algorithm.sharedSecretKey(
      keyPair: userKeyPair,
      remotePublicKey: serverPublicKey,
    );

    // --- AES-GCM decrypt ---
    final aes = AesGcm.with256bits();
    final decryptedBytes = await aes.decrypt(
      secretBox,
      secretKey: sharedSecretKey,
    );

    return utf8.decode(decryptedBytes);
  }
}
