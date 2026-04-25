enum OfflineTransferStatus {
  pendingNfc,
  pendingSettlement,
  settled,
  rejected,
}

class OfflineTransfer {
  const OfflineTransfer({
    required this.txId,
    required this.amountCents,
    required this.receiverKid,
    required this.createdAt,
    required this.status,
    this.counterpartyLabel,
    this.memo,
    this.rejectReason,
    this.ackSignature,
  });

  final String txId;
  final int amountCents;
  final String receiverKid;
  final DateTime createdAt;
  final OfflineTransferStatus status;
  final String? counterpartyLabel;
  final String? memo;
  final String? rejectReason;
  final String? ackSignature;

  String get amountLabel => _formatMyR(amountCents);

  String get shortTxId {
    if (txId.length <= 6) {
      return txId;
    }

    return txId.substring(txId.length - 6);
  }

  OfflineTransfer copyWith({
    OfflineTransferStatus? status,
    String? counterpartyLabel,
    String? memo,
    String? rejectReason,
    String? ackSignature,
  }) {
    return OfflineTransfer(
      txId: txId,
      amountCents: amountCents,
      receiverKid: receiverKid,
      createdAt: createdAt,
      status: status ?? this.status,
      counterpartyLabel: counterpartyLabel ?? this.counterpartyLabel,
      memo: memo ?? this.memo,
      rejectReason: rejectReason ?? this.rejectReason,
      ackSignature: ackSignature ?? this.ackSignature,
    );
  }
}

String _formatMyR(int cents) {
  final absoluteCents = cents.abs();
  final value = (absoluteCents ~/ 100).toString();
  final fractional = (absoluteCents % 100).toString().padLeft(2, '0');
  return '${cents.isNegative ? '-' : ''}RM $value.$fractional';
}
