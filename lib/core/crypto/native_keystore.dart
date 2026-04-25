// lib/core/crypto/native_keystore.dart
//
// Flutter side of the Android Keystore MethodChannel bridge.
// The Ed25519 PRIVATE KEY stays in the Keystore (TEE/StrongBox) and
// NEVER crosses the FFI boundary into Dart.
//
// Kotlin side: android/app/src/main/kotlin/com/tng/finhack/keystore/SigningKeyManager.kt
// docs/07-mobile-app.md §6

import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeKeystore {
  static const _channel = MethodChannel('com.tng.finhack/keystore');

  /// Ensure the Ed25519 keypair exists in the Keystore (generates if absent).
  /// Returns the key alias (kid).
  static Future<String> ensureKey({required String serverChallenge}) async {
    final result = await _channel.invokeMethod<String>(
      'ensureKey',
      {'serverChallenge': serverChallenge},
    );
    if (result == null) throw const KeystoreException('ensureKey returned null');
    return result;
  }

  /// Sign [data] bytes using the Keystore-backed Ed25519 private key.
  /// Requires biometric/PIN unlock for amounts above the low-value threshold.
  static Future<Uint8List> sign(Uint8List data) async {
    final result = await _channel.invokeMethod<Uint8List>('sign', {'data': data});
    if (result == null) throw const KeystoreException('sign returned null');
    return result;
  }

  /// Returns the 32-byte raw Ed25519 public key.
  static Future<Uint8List> getPublicKey() async {
    final result = await _channel.invokeMethod<Uint8List>('getPublicKey');
    if (result == null) throw const KeystoreException('getPublicKey returned null');
    return result;
  }

  /// Returns the DER-encoded key attestation certificate chain bytes.
  static Future<Uint8List> getAttestationChain() async {
    final result = await _channel.invokeMethod<Uint8List>('getAttestationChain');
    if (result == null) throw const KeystoreException('getAttestationChain returned null');
    return result;
  }
}

class KeystoreException implements Exception {
  const KeystoreException(this.message);
  final String message;
  @override
  String toString() => 'KeystoreException: $message';
}
