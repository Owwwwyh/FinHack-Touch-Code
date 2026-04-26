import 'package:flutter/material.dart';

import '../../../domain/services/credit_scorer.dart';

class OfflineProfile extends StatelessWidget {
  const OfflineProfile({
    super.key,
    required this.offlineCap,
    required this.aiSafeBalance,
    required this.lastSync,
    required this.onRefresh,
    required this.policyVersion,
    required this.modelVersion,
    required this.confidence,
    required this.pendingOutgoingCents,
    required this.lifetimeTransactionCount,
    required this.isAiEligible,
    required this.modeLabel,
    required this.drivers,
  });
  final double offlineCap;
  final double aiSafeBalance;
  final String lastSync;
  final VoidCallback onRefresh;
  final String policyVersion;
  final String modelVersion;
  final double confidence;
  final int pendingOutgoingCents;
  final int lifetimeTransactionCount;
  final bool isAiEligible;
  final String modeLabel;
  final List<CreditScoreDriver> drivers;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
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
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Aisha Rahman',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A))),
                    const Text('+60 12-***-4821 · Verified',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined,
                              color: Color(0xFF059669), size: 10),
                          SizedBox(width: 3),
                          Text('Offline-Ready',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF059669))),
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
                    const Icon(Icons.auto_awesome,
                        color: Color(0xFF7C3AED), size: 16),
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
                      child: const Icon(Icons.refresh,
                          color: Color(0xFF94A3B8), size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'RM ${aiSafeBalance.toStringAsFixed(2)}',
                      key: const ValueKey('ai-score-balance'),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5),
                    ),
                    const Spacer(),
                    Text('Last sync · $lastSync',
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isAiEligible
                      ? '$modeLabel · ${(confidence * 100).round()}% confidence'
                      : 'Reload your manual offline wallet until you reach 600 lifetime transactions.',
                  style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.memory,
                          color: Color(0xFF7C3AED), size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Model $modelVersion · Policy $policyVersion',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5B21B6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (pendingOutgoingCents > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Color(0xFFB45309), size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'RM ${(pendingOutgoingCents / 100).toStringAsFixed(2)} reserved for pending settlement',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (drivers.isNotEmpty)
                  Column(
                    children: drivers.take(4).map((driver) {
                      final tone = driver.isPositive
                          ? const Color(0xFF059669)
                          : const Color(0xFFB45309);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              driver.isPositive
                                  ? Icons.trending_up
                                  : Icons.schedule,
                              color: tone,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                driver.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF334155),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              driver.value,
                              style: TextStyle(
                                fontSize: 10,
                                color: tone,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(
                  label: 'Offline Cap',
                  value: 'RM ${offlineCap.toStringAsFixed(2)}'),
              const SizedBox(width: 8),
              _StatCell(
                label: 'Lifetime Tx',
                value: '$lifetimeTransactionCount',
                icon: Icons.bar_chart_rounded,
              ),
              const SizedBox(width: 8),
              _StatCell(
                label: 'Mode',
                value: isAiEligible ? 'AI active' : 'Manual',
                icon: Icons.auto_awesome,
              ),
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
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF94A3B8), letterSpacing: 0.5)),
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
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
