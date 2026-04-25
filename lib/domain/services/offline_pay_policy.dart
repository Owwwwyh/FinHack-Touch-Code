import '../models/offline_transfer.dart';

class OfflinePayPolicy {
  const OfflinePayPolicy({
    this.safeOfflineBalanceCents = 12000,
    this.receiverKid = '01HW4…a3f4',
    this.policyVersion = 'v3.2026-04-22',
  });

  final int safeOfflineBalanceCents;
  final String receiverKid;
  final String policyVersion;

  AmountValidationResult validateAmountText(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return const AmountValidationResult.invalid('Enter an amount to continue.');
    }

    final amount = double.tryParse(normalized);
    if (amount == null || amount.isNaN || amount.isInfinite) {
      return const AmountValidationResult.invalid('Enter a valid numeric amount.');
    }

    if (amount <= 0) {
      return const AmountValidationResult.invalid('Amount must be greater than zero.');
    }

    final cents = (amount * 100).round();
    if (cents > safeOfflineBalanceCents) {
      return AmountValidationResult.invalid(
        'Amount exceeds your safe offline balance of ${_formatMyR(safeOfflineBalanceCents)}.',
      );
    }

    return AmountValidationResult.valid(cents);
  }

  OfflineTransfer createDraft({
    required int amountCents,
    required DateTime createdAt,
    String? receiverKid,
  }) {
    final txId = '01${createdAt.millisecondsSinceEpoch}${amountCents.toString().padLeft(4, '0')}';
    return OfflineTransfer(
      txId: txId,
      amountCents: amountCents,
      receiverKid: receiverKid ?? this.receiverKid,
      createdAt: createdAt,
      status: OfflineTransferStatus.pendingNfc,
    );
  }
}

class AmountValidationResult {
  const AmountValidationResult._({
    required this.isValid,
    required this.amountCents,
    required this.message,
  });

  const AmountValidationResult.valid(int amountCents)
      : this._(isValid: true, amountCents: amountCents, message: null);

  const AmountValidationResult.invalid(String message)
      : this._(isValid: false, amountCents: null, message: message);

  final bool isValid;
  final int? amountCents;
  final String? message;
}

String _formatMyR(int cents) {
  final absoluteCents = cents.abs();
  final value = (absoluteCents ~/ 100).toString();
  final fractional = (absoluteCents % 100).toString().padLeft(2, '0');
  return '${cents.isNegative ? '-' : ''}RM $value.$fractional';
}
