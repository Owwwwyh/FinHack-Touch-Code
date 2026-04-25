import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/payment_providers.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/mode_provider.dart';
import '../../domain/models/offline_transfer.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(modeProvider) == AppMode.offline;
    final outbox = ref.watch(outboxProvider);
    final inbox = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Tokens'),
        backgroundColor: isOffline ? AppTheme.offlineGrey : null,
        foregroundColor: isOffline ? Colors.white : null,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Outbox ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'Sent (pending settlement)'),
          if (outbox.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No pending sent tokens',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...outbox.map((t) => _PendingTile(
                  label: 'Merchant: ${t.receiverKid.substring(0, 8)}…',
                  amount: (t.amountCents / 100).toStringAsFixed(2),
                  kid: t.txId.substring(t.txId.length - 4),
                  isSent: true,
                )),

          const SizedBox(height: 16),

          // ── Inbox ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'Received (pending settlement)'),
          if (inbox.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('No pending received tokens',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            ...inbox.map((t) => _PendingTile(
                  label: 'Payer: unknown',
                  amount: (t.amountCents / 100).toStringAsFixed(2),
                  kid: t.txId.substring(t.txId.length - 4),
                  isSent: false,
                )),

          const SizedBox(height: 24),
          // Settle button
          FilledButton.icon(
            onPressed: (outbox.isEmpty && inbox.isEmpty)
                ? null
                : () async {
                    // Combine all tokens for settlement
                    final tokens = outbox.map((t) => 'jws_token_${t.txId}').toList();

                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settling tokens with backend...')));

                    // In a real app, this would be a single call with batch_id
                    final results = await ref.read(tokensApiProvider).settle(tokens);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Settled ${results.length} tokens successfully!')));
                      
                      // For demo: clear outbox/inbox on success
                      // In production, we'd wait for specific tx_id results
                    }
                  },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Settle all pending'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.offlineGrey)),
      );
}

class _PendingTile extends StatelessWidget {
  const _PendingTile(
      {required this.label,
      required this.amount,
      required this.kid,
      required this.isSent});
  final String label, amount, kid;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSent
              ? AppTheme.tngBlue.withValues(alpha: 0.12)
              : AppTheme.settled.withValues(alpha: 0.12),
          child: Icon(isSent ? Icons.nfc : Icons.arrow_downward,
              color: isSent ? AppTheme.tngBlue : AppTheme.settled, size: 18),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('…$kid · RM $amount',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.pending.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('pending',
              style: TextStyle(
                  color: AppTheme.pending,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
