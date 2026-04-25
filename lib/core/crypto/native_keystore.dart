import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Platform channel bridge to Android Keystore signing operations
///
/// Calls Kotlin SigningKeyManager via method channel
/// Never holds the private key in Dart; only sends data to sign
class NativeKeystore {
  static const platform = MethodChannel('com.tng.finhack/keystore');

  /// Generate a new signing key pair
  ///
  /// [alias]: Key alias (e.g., "tng_signing_v1")
  /// [attestationChallenge]: Challenge bytes from server for attestation
  /// Returns: 32-byte Ed25519 public key
  static Future<Uint8List> generateKey(
    String alias,
    Uint8List attestationChallenge,
  ) async {
    try {
      final result = await platform.invokeMethod<Uint8List>('generateKey', {
        'alias': alias,
        'attestationChallenge': attestationChallenge,
      });

      if (result == null) {
        throw Exception('generateKey returned null');
      }

      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to generate key: ${e.message}');
    }
  }

  /// Sign data with the private key stored in Keystore
  ///
  /// [alias]: Key alias
  /// [data]: Data to sign
  /// Returns: Signature bytes
  static Future<Uint8List> sign(
    String alias,
    Uint8List data,
  ) async {
    try {
      final result = await platform.invokeMethod<Uint8List>('sign', {
        'alias': alias,
        'data': data,
      });

      if (result == null) {
        throw Exception('sign returned null');
      }

      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to sign data: ${e.message}');
    }
  }

  /// Get the public key for a given key alias
  ///
  /// [alias]: Key alias
  /// Returns: 32-byte Ed25519 public key
  static Future<Uint8List> getPublicKey(String alias) async {
    try {
      final result = await platform.invokeMethod<Uint8List>('getPublicKey', {
        'alias': alias,
      });

      if (result == null) {
        throw Exception('getPublicKey returned null');
      }

      return result;
    } on PlatformException catch (e) {
      throw Exception('Failed to get public key: ${e.message}');
    }
  }

  /// Check if a key exists
  ///
  /// [alias]: Key alias
  /// Returns: true if key exists
  static Future<bool> keyExists(String alias) async {
    try {
      final result = await platform.invokeMethod<bool>('keyExists', {
        'alias': alias,
      });

      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception('Failed to check key existence: ${e.message}');
    }
  }

  /// List all available keys
  ///
  /// Returns: List of key aliases
  static Future<List<String>> listKeys() async {
    try {
      final result = await platform.invokeMethod<List<dynamic>>('listKeys');

      if (result == null) {
        return [];
      }

      return result.cast<String>();
    } on PlatformException catch (e) {
      throw Exception('Failed to list keys: ${e.message}');
    }
  }

  /// Delete a key
  ///
  /// [alias]: Key alias
  static Future<void> deleteKey(String alias) async {
    try {
      await platform.invokeMethod<void>('deleteKey', {
        'alias': alias,
      });
    } on PlatformException catch (e) {
      throw Exception('Failed to delete key: ${e.message}');
    }
  }

  /// Get attestation certificate chain for a key
  /// Used during registration to prove hardware-backed storage
  ///
  /// [alias]: Key alias
  /// Returns: List of base64-encoded certificate PEM strings
  static Future<List<String>> getAttestationCertificateChain(
    String alias,
  ) async {
    try {
      final result = await platform
          .invokeMethod<List<dynamic>>('getAttestationCertificateChain', {
        'alias': alias,
      });

      if (result == null) {
        return [];
      }

      return result.cast<String>();
    } on PlatformException catch (e) {
      throw Exception('Failed to get attestation chain: ${e.message}');
    }
  }
}
