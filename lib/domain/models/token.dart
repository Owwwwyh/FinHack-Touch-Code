// lib/domain/models/token.dart
//
// Immutable domain models for offline payment tokens.

import 'dart:typed_data';

/// Status of a token in the local outbox/inbox.
enum TxStatus {
  pendingNfc,
  pendingSettlement,
  settled,
  rejected,
}

/// An offline payment token (sender side — in outbox).
class OfflineToken {
  const OfflineToken({
    required this.txId,
    required this.jws,
    required this.amountMyr,
    required this.receiverKid,
    required this.createdAt,
    required this.status,
    this.rejectReason,
    this.ackSig,
  });

  final String txId;
  final String jws;
  final double amountMyr;
  final String receiverKid;
  final DateTime createdAt;
  final TxStatus status;
  final String? rejectReason;
  final String? ackSig;

  bool get isPending => status == TxStatus.pendingSettlement;
  bool get isSettled => status == TxStatus.settled;
  bool get isRejected => status == TxStatus.rejected;

  String get shortReceiverId => receiverKid.length >= 4
      ? receiverKid.substring(receiverKid.length - 4)
      : receiverKid;
}

/// A received token (receiver side — in inbox).
class ReceivedToken {
  const ReceivedToken({
    required this.txId,
    required this.jws,
    required this.amountMyr,
    required this.senderKid,
    required this.receivedAt,
    required this.status,
    this.rejectReason,
  });

  final String txId;
  final String jws;
  final double amountMyr;
  final String senderKid;
  final DateTime receivedAt;
  final TxStatus status;
  final String? rejectReason;

  String get shortSenderId => senderKid.length >= 4
      ? senderKid.substring(senderKid.length - 4)
      : senderKid;
}

/// Result of a single token settlement.
class SettlementResult {
  const SettlementResult({
    required this.txId,
    required this.status,
    this.settledAt,
    this.reason,
  });

  final String txId;
  final String status; // 'SETTLED' | 'REJECTED'
  final DateTime? settledAt;
  final String? reason;

  bool get isSettled => status == 'SETTLED';
}
