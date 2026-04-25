import 'package:flutter/material.dart';

class TngBottomNav extends StatelessWidget {
  const TngBottomNav({super.key, required this.activeTab, required this.onTabChanged});
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  static const _labels = ['Home', 'Finance', 'Scan', 'Inbox', 'Me'];
  static const _icons = [
    Icons.home_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.qr_code_scanner,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];

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
          for (int i = 0; i < _labels.length; i++)
            if (i == 2)
              GestureDetector(
                onTap: () => onTabChanged(i),
                child: Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0066FF), Color(0xFF003DB8)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x550066FF), blurRadius: 12, offset: Offset(0, 4))],
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
                ),
              )
            else
              GestureDetector(
                onTap: () => onTabChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[i],
                        size: 22,
                        color: activeTab == i ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: activeTab == i ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
