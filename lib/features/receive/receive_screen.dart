import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../domain/models/offline_transfer.dart';
import '../offline/offline_payment_controller.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlinePaymentControllerProvider);
    final latest = state.latestIncomingReceipt;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Inbox')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (latest != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment received',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latest.amountLabel,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'From ${latest.counterpartyLabel ?? latest.receiverKid}',
                    ),
                    const SizedBox(height: 4),
                    const Text('Pending settlement'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              ref
                                  .read(
                                      offlinePaymentControllerProvider.notifier)
                                  .clearLatestIncomingReceipt();
                              context.go(RoutePaths.request);
                            },
                            child: const Text('New request'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Waiting for tap 2',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This device stays ready as the merchant receiver. After the payer taps back, the signed token will appear here.',
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending receipts (${state.inbox.length})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (state.inbox.isEmpty)
                    const Text('No tokens received yet')
                  else
                    for (final transfer in state.inbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReceiveTile(transfer: transfer),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiveTile extends StatelessWidget {
  const _ReceiveTile({required this.transfer});

  final OfflineTransfer transfer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.call_received, color: Color(0xFF22C55E)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.amountLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'From ${transfer.counterpartyLabel ?? transfer.receiverKid}',
                  ),
                  Text(
                    'tx …${transfer.shortTxId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const _StatusChip(status: OfflineTransferStatus.pendingSettlement),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OfflineTransferStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      OfflineTransferStatus.pendingNfc => 'Pending NFC',
      OfflineTransferStatus.pendingSettlement => 'Pending settlement',
      OfflineTransferStatus.settled => 'Settled',
      OfflineTransferStatus.rejected => 'Rejected',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF166534),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
