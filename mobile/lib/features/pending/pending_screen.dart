import 'package:flutter/material.dart';

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Tokens')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Outbox section
          const Text('Outbox (sent, awaiting settlement)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          _PendingTile(txId: '…a3f4', amount: 'RM 8.50', direction: 'OUT', time: '2 min ago'),
          _PendingTile(txId: '…b7c1', amount: 'RM 12.00', direction: 'OUT', time: '15 min ago'),
          const SizedBox(height: 24),
          // Inbox section
          const Text('Inbox (received, awaiting settlement)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          _PendingTile(txId: '…d2e8', amount: 'RM 25.00', direction: 'IN', time: '5 min ago'),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Trigger settle pending
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Settle All Now'),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends StatelessWidget {
  final String txId;
  final String amount;
  final String direction;
  final String time;

  const _PendingTile({
    required this.txId,
    required this.amount,
    required this.direction,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final isIn = direction == 'IN';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isIn ? const Color(0xFFF0FDF4) : const Color(0xFFEEF5FF),
          child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? const Color(0xFF16A34A) : const Color(0xFF0061A8)),
        ),
        title: Text('$amount ${isIn ? 'from' : 'to'} $txId', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(time),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text('PENDING', style: TextStyle(color: Color(0xFFFFA000), fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
