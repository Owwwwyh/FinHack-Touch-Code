import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Dart-side wrapper for the `com.tng.finhack/nfc` platform channel.
/// Drives the NFC reader mode for the sender (Pay) flow.
///
/// Call order:
///   1. [selectAndGetReceiverPub] — starts reader mode, sends SELECT, returns receiver pub key
///   2. [sendJwsAndGetAck]         — sends JWS chunks, retrieves ack signature
///   3. [stopReaderMode]           — cleans up (called in finally block)
class NfcSender {
  static const _channel = MethodChannel('com.tng.finhack/nfc');

  /// Starts NFC reader mode and sends SELECT AID.
  /// Returns the 32-byte receiver public key, or null on error.
  static Future<Uint8List?> selectAndGetReceiverPub() async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('selectAndGetReceiverPub');
      return result;
    } on PlatformException catch (e) {
      throw NfcException(e.code, e.message ?? 'Unknown NFC error');
    }
  }

  /// Sends the signed JWS token in chunks and retrieves the receiver's ack signature.
  /// Returns the 64-byte raw ack signature, or throws [NfcException] on failure.
  static Future<Uint8List> sendJwsAndGetAck(String jwsToken) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'sendJwsAndGetAck',
        {'jws': jwsToken},
      );
      if (result == null) throw const NfcException('NFC_ERROR', 'Null ack response');
      return result;
    } on PlatformException catch (e) {
      throw NfcException(e.code, e.message ?? 'Unknown NFC error');
    }
  }

  /// Disables NFC reader mode and closes any open IsoDep connection.
  static Future<void> stopReaderMode() async {
    try {
      await _channel.invokeMethod<void>('stopReaderMode');
    } on PlatformException {
      // Best-effort cleanup — ignore errors
    }
  }
}

class NfcException implements Exception {
  final String code;
  final String message;

  const NfcException(this.code, this.message);

  @override
  String toString() => 'NfcException[$code]: $message';
}
