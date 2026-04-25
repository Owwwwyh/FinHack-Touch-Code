import 'package:flutter/material.dart';

class RecentTransactions extends StatelessWidget {
  const RecentTransactions({super.key});

  static const _txns = [
    _Txn(Icons.coffee, 'Coffee Bean', 'Today, 9:24 AM', '-RM 18.50',
        Color(0xFFFED7AA), Color(0xFFEA580C), false),
    _Txn(Icons.directions_car, 'PLUS Highway Toll', 'Today, 8:02 AM',
        '-RM 12.30', Color(0xFFBFDBFE), Color(0xFF2563EB), false),
    _Txn(Icons.bolt, 'TNB Electricity', 'Yesterday', '-RM 145.00',
        Color(0xFFFDE68A), Color(0xFFD97706), false),
    _Txn(Icons.shopping_bag, 'Reload from Maybank', '24 Apr', '+RM 200.00',
        Color(0xFFA7F3D0), Color(0xFF059669), true),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Recent Activity',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
                const Spacer(),
                Text('View all',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          for (int i = 0; i < _txns.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
            _TxnTile(txn: _txns[i]),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Txn {
  const _Txn(this.icon, this.label, this.time, this.amount, this.bg, this.fg,
      this.credit);
  final IconData icon;
  final String label;
  final String time;
  final String amount;
  final Color bg;
  final Color fg;
  final bool credit;
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn});
  final _Txn txn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: txn.bg, shape: BoxShape.circle),
            child: Icon(txn.icon, color: txn.fg, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.label,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(txn.time,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Text(
            txn.amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: txn.credit
                  ? const Color(0xFF059669)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
