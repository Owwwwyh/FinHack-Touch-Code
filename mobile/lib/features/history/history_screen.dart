import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = [
      ('Aida Stall', '-RM 8.50', true, 'Settled'),
      ('Top-up via FPX', '+RM 50.00', true, 'Settled'),
      ('Faiz Ride', '-RM 12.00', true, 'Settled'),
      ('MRT Reload', '+RM 30.00', true, 'Settled'),
      ('Kopi Counter', '-RM 4.50', true, 'Settled'),
      ('Transfer from Siti', '+RM 25.00', false, 'Pending'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final item = transactions[index];
          final isIn = item.$2.startsWith('+');
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isIn ? const Color(0xFFF0FDF4) : const Color(0xFFEEF5FF),
              child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? const Color(0xFF16A34A) : const Color(0xFF0061A8)),
            ),
            title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              item.$4,
              style: TextStyle(color: item.$3 ? const Color(0xFF16A34A) : const Color(0xFFFFA000), fontSize: 12),
            ),
            trailing: Text(item.$2, style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? const Color(0xFF16A34A) : Colors.black87)),
          );
        },
      ),
    );
  }
}
