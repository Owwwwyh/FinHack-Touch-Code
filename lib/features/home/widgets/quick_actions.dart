import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ActionBtn(
              icon: Icons.qr_code,
              label: 'Pay',
              bg: Color(0xFFEFF6FF),
              fg: Color(0xFF2563EB)),
          _ActionBtn(
              icon: Icons.qr_code_scanner,
              label: 'Scan',
              bg: Color(0xFFECFDF5),
              fg: Color(0xFF059669)),
          _ActionBtn(
              icon: Icons.send,
              label: 'Transfer',
              bg: Color(0xFFFFF7ED),
              fg: Color(0xFFEA580C)),
          _ActionBtn(
              icon: Icons.account_balance_wallet,
              label: 'Reload',
              bg: Color(0xFFF5F3FF),
              fg: Color(0xFF7C3AED)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: fg, size: 24),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
      ],
    );
  }
}
