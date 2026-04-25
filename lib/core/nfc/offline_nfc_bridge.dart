import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/models/payment_request.dart';
import 'nfc_sender.dart';

class ReceivedOfflineToken {
  const ReceivedOfflineToken({
    required this.jws,
    required this.ackSignature,
  });

  final String jws;
  final String? ackSignature;
}

abstract class OfflineNfcBridge {
  Stream<PaymentRequest> get paymentRequests;
  Stream<ReceivedOfflineToken> get receivedTokens;

  Future<Uint8List> sendPaymentRequest(PaymentRequest request);

  Future<Uint8List> completePaymentTap({
    required String jws,
    required Uint8List expectedReceiverPublicKey,
  });

  Future<void> stopReaderMode();

  void dispose();
}

class PlatformOfflineNfcBridge implements OfflineNfcBridge {
  static const _paymentRequestChannel =
      EventChannel('com.tng.finhack/payment_requests');
  static const _inboxChannel = EventChannel('com.tng.finhack/inbox');

  @override
  Stream<PaymentRequest> get paymentRequests {
    return _paymentRequestChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is! Map) {
        throw const FormatException('Invalid payment request event');
      }
      final raw = event['requestJson'] as String? ?? '';
      return PaymentRequest.fromJsonString(raw);
    });
  }

  @override
  Stream<ReceivedOfflineToken> get receivedTokens {
    return _inboxChannel.receiveBroadcastStream().map((dynamic event) {
      if (event is! Map) {
        throw const FormatException('Invalid inbox event');
      }
      return ReceivedOfflineToken(
        jws: event['jws'] as String? ?? '',
        ackSignature: event['ackSig'] as String?,
      );
    });
  }

  @override
  Future<Uint8List> sendPaymentRequest(PaymentRequest request) {
    return NfcSender.sendPaymentRequest(request.toJsonString());
  }

  @override
  Future<Uint8List> completePaymentTap({
    required String jws,
    required Uint8List expectedReceiverPublicKey,
  }) {
    return NfcSender.completePaymentTap(
      jwsToken: jws,
      expectedReceiverPublicKey: expectedReceiverPublicKey,
    );
  }

  @override
  Future<void> stopReaderMode() => NfcSender.stopReaderMode();

  @override
  void dispose() {}
}
