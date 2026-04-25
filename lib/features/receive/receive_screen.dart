// lib/features/receive/receive_screen.dart
// Implements wireframe 4.5 — Receive screen (HCE waiting state)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              // NFC icon
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.tngBlue.withValues(alpha: 0.1),
                  border: Border.all(color: AppTheme.tngBlue.withValues(alpha: 0.3), width: 2),
                ),
                child: const Icon(Icons.nfc, color: AppTheme.tngBlue, size: 60),
              ),
              const SizedBox(height: 24),
              const Text('Hold sender\'s phone near this one',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Waiting for NFC tap...',
                style: TextStyle(color: AppTheme.offlineGrey, fontSize: 15)),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
              const Spacer(),
              // Recent received
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Recently received',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              _ReceivedTile(amount: '12.00', from: 'a3f4', status: 'pending'),
              _ReceivedTile(amount: '5.00',  from: 'b7c2', status: 'settled'),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({required this.amount, required this.from, required this.status});
  final String amount, from, status;

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppTheme.settled.withValues(alpha: 0.12),
        child: const Icon(Icons.arrow_downward, color: AppTheme.settled, size: 18),
      ),
      title: Text('Received RM $amount from …$from',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPending ? AppTheme.pending.withValues(alpha: 0.15) : AppTheme.settled.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(isPending ? 'pending' : 'settled',
          style: TextStyle(color: isPending ? AppTheme.pending : AppTheme.settled, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
