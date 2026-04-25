import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Platform channel to Android Keystore for Ed25519 key management and signing.
class NativeKeystore {
  static const _channel = MethodChannel('com.tng.finhack/keystore');

  /// Ensure the Ed25519 key exists; generate if not. Returns the kid.
  Future<String> ensureKey() async {
    return await _channel.invokeMethod<String>('ensureKey') ?? '';
  }

  /// Sign data with the Ed25519 private key from Android Keystore.
  Future<Uint8List> sign(Uint8List data) async {
    final result = await _channel.invokeMethod<Uint8List>('sign', {'data': data});
    return result ?? Uint8List(0);
  }

  /// Get the Ed25519 public key bytes (32 bytes raw).
  Future<Uint8List> getPublicKey() async {
    final result = await _channel.invokeMethod<Uint8List>('getPublicKey');
    return result ?? Uint8List(0);
  }

  /// Get the Android Key Attestation certificate chain.
  Future<Uint8List> getAttestationChain() async {
    final result = await _channel.invokeMethod<Uint8List>('getAttestationChain');
    return result ?? Uint8List(0);
  }

  /// Check if a key already exists.
  Future<bool> hasKey() async {
    return await _channel.invokeMethod<bool>('hasKey') ?? false;
  }
}
