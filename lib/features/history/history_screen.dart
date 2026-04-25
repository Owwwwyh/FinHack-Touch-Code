// lib/features/history/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/mode_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(modeProvider) == AppMode.offline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: isOffline ? AppTheme.offlineGrey : null,
        foregroundColor: isOffline ? Colors.white : null,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), 
          onPressed: () => context.go('/home')
        ),
      ),
      body: ListView(
        children: const [
          _HistoryTile(date: 'Today', label: 'Top-up via FPX', amount: '+RM 50.00', status: 'settled', isIn: true),
          _HistoryTile(date: 'Today', label: 'Aida Stall (NFC)', amount: '−RM 8.50', status: 'settled', isIn: false),
          _HistoryTile(date: 'Yesterday', label: 'Grab Rider (NFC)', amount: '−RM 12.00', status: 'rejected', isIn: false),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.date, required this.label, required this.amount, required this.status, required this.isIn});
  final String date, label, amount, status;
  final bool isIn;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    final color = isRejected ? Colors.red : (isIn ? AppTheme.settled : const Color(0xFF1F2937));
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIn
          ? AppTheme.settled.withValues(alpha: 0.12)
          : AppTheme.tngBlue.withValues(alpha: 0.12),
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.nfc,
          color: isIn ? AppTheme.settled : AppTheme.tngBlue, size: 18,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('$date · ${isRejected ? 'Rejected (Nonce reused)' : 'Settled'}',
        style: TextStyle(
          fontSize: 12,
          color: isRejected ? Colors.red : AppTheme.offlineGrey,
        )),
      trailing: Text(amount,
        style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 15,
          color: color,
          decoration: isRejected ? TextDecoration.lineThrough : null,
        )),
    );
  }
}
