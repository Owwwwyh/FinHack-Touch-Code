import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../domain/models/offline_transfer.dart';
import '../offline/offline_payment_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(offlinePaymentControllerProvider);
    final connectivity = ref.watch(connectivityServiceProvider);
    final connectivityService = ref.read(connectivityServiceProvider.notifier);

    final outbox = payments.outbox.map((t) => (transfer: t, sent: true));
    final inbox = payments.inbox.map((t) => (transfer: t, sent: false));
    final all = [...outbox, ...inbox].toList()
      ..sort((a, b) => b.transfer.createdAt.compareTo(a.transfer.createdAt));

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: RefreshIndicator(
        onRefresh: () async {
          if (connectivity.hasNetwork) {
            connectivityService.markSyncSuccess();
          }
        },
        child: all.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: all.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = all[index];
                  return _TransferRow(
                    transfer: item.transfer,
                    sent: item.sent,
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xFFCBD5E1)),
        SizedBox(height: 12),
        Text(
          'No transactions yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
        ),
      ],
    );
  }
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({required this.transfer, required this.sent});

  final OfflineTransfer transfer;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (transfer.status) {
      OfflineTransferStatus.settled => const Color(0xFF059669),
      OfflineTransferStatus.rejected => const Color(0xFFDC2626),
      _ => const Color(0xFFD97706),
    };
    final statusLabel = switch (transfer.status) {
      OfflineTransferStatus.settled => 'Settled',
      OfflineTransferStatus.rejected => 'Rejected',
      OfflineTransferStatus.pendingSettlement => 'Pending',
      OfflineTransferStatus.pendingNfc => 'Pending NFC',
    };
    final now = DateTime.now();
    final age = now.difference(transfer.createdAt);
    final timeLabel = age.inMinutes < 1
        ? 'just now'
        : age.inHours < 1
            ? '${age.inMinutes}m ago'
            : age.inDays < 1
                ? '${age.inHours}h ago'
                : '${age.inDays}d ago';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: sent
                    ? const Color(0xFFFFF7ED)
                    : const Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                sent ? Icons.arrow_upward : Icons.arrow_downward,
                color: sent ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.counterpartyLabel ??
                        (sent ? 'Sent' : 'Received'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${sent ? '-' : '+'}${transfer.amountLabel}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: sent ? const Color(0xFF0F172A) : const Color(0xFF16A34A),
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
