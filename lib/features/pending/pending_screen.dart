import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class PendingScreen extends ConsumerWidget {
  const PendingScreen({super.key});

  static const _demoOutbox = [
    ('Aida Stall', '8.50', 'b7c2', false),
    ('Grab Rider',  '12.00', 'a3f4', false),
  ];

  static const _demoInbox = [
    ('Jane Lee', '50.00', 'd9f1', true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Tokens'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Outbox ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'Sent (pending settlement)'),
          ..._demoOutbox.map((t) => _PendingTile(
            label: t.$1, amount: t.$2, kid: t.$3, isSent: !t.$4)),

          const SizedBox(height: 16),

          // ── Inbox ─────────────────────────────────────────────────────────
          const _SectionHeader(title: 'Received (pending settlement)'),
          ..._demoInbox.map((t) => _PendingTile(
            label: t.$1, amount: t.$2, kid: t.$3, isSent: !t.$4)),

          const SizedBox(height: 24),
          // Settle button
          FilledButton.icon(
            onPressed: () async {
              // Simulate getting tokens from local DB
              final mockTokens = _demoOutbox.map((t) => 'jws_token_${t.$3}').toList();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settling tokens with backend...')));
              
              final results = await ref.read(tokensApiProvider).settle(mockTokens);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Settled ${results.length} tokens successfully!')));
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
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.offlineGrey)),
  );
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.label, required this.amount, required this.kid, required this.isSent});
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
            style: TextStyle(color: AppTheme.pending, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}
