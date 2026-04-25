import 'package:flutter/material.dart';

class OfflineProfile extends StatelessWidget {
  const OfflineProfile({
    super.key,
    required this.offlineCap,
    required this.aiSafeBalance,
    required this.lastSync,
    required this.onRefresh,
  });
  final double offlineCap;
  final double aiSafeBalance;
  final String lastSync;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text('A',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aisha Rahman',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                    const Text('+60 12-***-4821 · Verified',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, color: Color(0xFF059669), size: 10),
                          SizedBox(width: 3),
                          Text('Offline-Ready', style: TextStyle(fontSize: 10, color: Color(0xFF059669))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFF5F3FF), Color(0xFFEFF6FF)],
              ),
              border: Border.all(color: const Color(0xFFDDD6FE)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'AI SAFE BALANCE',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF7C3AED),
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onRefresh,
                      child: const Icon(Icons.refresh, color: Color(0xFF94A3B8), size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${aiSafeBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5),
                    ),
                    const Spacer(),
                    Text('Last sync · $lastSync',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculated from your spending pattern, history & credit score.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(label: 'Offline Cap', value: 'RM ${offlineCap.toStringAsFixed(2)}'),
              const SizedBox(width: 8),
              const _StatCell(label: 'NFC ID', value: '#A4F2', icon: Icons.tag),
              const SizedBox(width: 8),
              const _StatCell(label: 'Card', value: '••4821', icon: Icons.credit_card),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 11, color: const Color(0xFF0F172A)),
                  const SizedBox(width: 2),
                ],
                Text(value,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
