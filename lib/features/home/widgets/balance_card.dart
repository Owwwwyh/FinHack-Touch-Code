import 'package:flutter/material.dart';

class BalanceCard extends StatefulWidget {
  const BalanceCard({super.key});

  @override
  State<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<BalanceCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0066FF), Color(0xFF0057E0), Color(0xFF003DB8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003DB8).withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TNG eWallet Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _hidden ? 'RM ••••••' : 'RM 1,284.50',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() => _hidden = !_hidden),
                          child: Icon(
                            _hidden ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoChip(label: 'GO+ Earnings', value: 'RM 12.84'),
              const SizedBox(width: 10),
              _InfoChip(label: 'Rewards', value: '2,450 pts'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
