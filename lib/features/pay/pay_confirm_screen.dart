import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../domain/models/offline_transfer.dart';
import '../home/offline/offline_score_provider.dart';
import '../offline/offline_payment_controller.dart';

class PayConfirmScreen extends ConsumerWidget {
  const PayConfirmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlinePaymentControllerProvider);
    final notifier = ref.read(offlinePaymentControllerProvider.notifier);
    final request = state.incomingRequest;
    final score = ref.watch(baseOfflineScoreProvider);
    final latestReceipt = state.latestOutgoingReceipt;
    final pendingOutgoingCents = _pendingOutgoingCents(state.outbox);
    final availableSafeBalanceCents = score.availableSafeBalanceCents(
        pendingOutgoingCents: pendingOutgoingCents);

    ref.listen(
      offlinePaymentControllerProvider.select((value) => value.errorMessage),
      (previous, next) {
        if (next != null && next.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
          notifier.dismissError();
        }
      },
    );

    if (latestReceipt != null && request == null) {
      return _PaymentSentView(
        transfer: latestReceipt,
        onDone: () {
          notifier.clearLatestOutgoingReceipt();
          context.go(RoutePaths.home);
        },
      );
    }

    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pay Confirm')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No incoming payment request right now.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Back home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final canAuthorize = !request.isExpired(DateTime.now()) &&
        request.amountCents <= availableSafeBalanceCents;
    final afterPayment = math.max(
      0,
      availableSafeBalanceCents - request.amountCents,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Pay Confirm')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Request Received',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    request.amountLabel,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('To: ${request.receiver.displayName}'),
                  if (request.memo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Memo: ${request.memo}'),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Safe offline balance: ${_formatMyr(availableSafeBalanceCents)}',
                  ),
                  Text(
                    'After payment: ${_formatMyr(afterPayment)}',
                  ),
                  Text(
                    'Policy ${score.policyVersion} · model ${score.modelVersion}',
                  ),
                  if (pendingOutgoingCents > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_formatMyr(pendingOutgoingCents)} already queued for settlement.',
                    ),
                  ],
                  if (!canAuthorize) ...[
                    const SizedBox(height: 12),
                    Text(
                      request.isExpired(DateTime.now())
                          ? 'Request expired. Ask the merchant to resend.'
                          : 'Amount exceeds your safe offline balance.',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!state.hasPendingTapBack)
            FilledButton.icon(
              onPressed: canAuthorize && !state.isSigning
                  ? () => notifier.authorizeIncomingRequest()
                  : null,
              icon: const Icon(Icons.lock_open),
              label: Text(
                state.isSigning ? 'Authorizing...' : 'Authorize payment',
              ),
            )
          else
            FilledButton.icon(
              onPressed: state.isSendingPayment
                  ? null
                  : () => notifier.completeTapBack(),
              icon: const Icon(Icons.nfc),
              label: Text(
                state.isSendingPayment
                    ? 'Tap 2 in progress...'
                    : 'Tap back to pay',
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              notifier.cancelIncomingRequest();
              context.go(RoutePaths.home);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _PaymentSentView extends StatelessWidget {
  const _PaymentSentView({
    required this.transfer,
    required this.onDone,
  });

  final OfflineTransfer transfer;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment sent')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment sent',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    transfer.amountLabel,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'To: ${transfer.counterpartyLabel ?? transfer.receiverKid}'),
                  const SizedBox(height: 4),
                  const Text('Pending settlement'),
                  const SizedBox(height: 16),
                  Text('Ref: …${transfer.shortTxId}'),
                  if (transfer.ackSignature != null) ...[
                    const SizedBox(height: 8),
                    const Text('Receiver ack captured for audit.'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

String _formatMyr(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'RM $whole.$fraction';
}

int _pendingOutgoingCents(List<OfflineTransfer> outbox) {
  return outbox
      .where(
        (transfer) =>
            transfer.status != OfflineTransferStatus.rejected &&
            transfer.status != OfflineTransferStatus.settled,
      )
      .fold<int>(
        0,
        (total, transfer) => total + transfer.amountCents,
      );
}
