import 'dart:typed_data';

import 'package:flutter/services.dart';

class NfcSender {
  static const _channel = MethodChannel('com.tng.finhack/nfc');

  static Future<Uint8List> sendPaymentRequest(String requestJson) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'sendPaymentRequest',
        {'requestJson': requestJson},
      );
      if (result == null) {
        throw const NfcException(
            'NFC_ERROR', 'Missing payer public key response');
      }
      return result;
    } on PlatformException catch (e) {
      throw NfcException(e.code, e.message ?? 'Unknown NFC error');
    }
  }

  static Future<Uint8List> completePaymentTap({
    required String jwsToken,
    required Uint8List expectedReceiverPublicKey,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'completePaymentTap',
        {
          'jws': jwsToken,
          'expectedReceiverPublicKey': expectedReceiverPublicKey,
        },
      );
      if (result == null) {
        throw const NfcException('NFC_ERROR', 'Null ack response');
      }
      return result;
    } on PlatformException catch (e) {
      throw NfcException(e.code, e.message ?? 'Unknown NFC error');
    }
  }

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
