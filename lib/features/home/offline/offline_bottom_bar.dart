import 'package:flutter/material.dart';

class OfflineBottomBar extends StatelessWidget {
  const OfflineBottomBar({
    super.key,
    required this.onNfcTap,
    required this.currentView,
    required this.onViewChanged,
  });
  final VoidCallback onNfcTap;
  final String currentView;
  final ValueChanged<String> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _TabBtn(
            icon: Icons.person_outline,
            label: 'Profile',
            active: currentView == 'home',
            onTap: () => onViewChanged('home'),
          ),
          GestureDetector(
            onTap: onNfcTap,
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Color(0x553B82F6),
                      blurRadius: 12,
                      offset: Offset(0, 4))
                ],
              ),
              child: const Icon(Icons.nfc, color: Colors.white, size: 28),
            ),
          ),
          _TabBtn(
            icon: Icons.receipt_long_outlined,
            label: 'Queue',
            active: currentView == 'queue',
            onTap: () => onViewChanged('queue'),
          ),
        ],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn(
      {required this.icon,
      required this.label,
      required this.active,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}
