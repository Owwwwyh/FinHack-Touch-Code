// lib/features/score/score_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Offline Limit'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: const Column(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.tngBlue, size: 48),
                  SizedBox(height: 16),
                  Text('AI-Powered Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 12),
                  Text(
                    'Your safe offline limit is dynamically calculated by our on-device AI to protect your funds if your phone is lost while offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.offlineGrey, fontSize: 14, height: 1.5),
                  ),
                  SizedBox(height: 32),
                  _StatRow(label: 'Current Limit', value: 'RM 120.00', highlight: true),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  _StatRow(label: 'Total Available Balance', value: 'RM 248.50'),
                  Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  _StatRow(label: 'Last Calculated', value: 'Today, 09:30 AM'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('How it works', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const _FeatureRow(icon: Icons.history, title: 'Transaction History', desc: 'Analyzes your typical offline spending patterns.'),
            const _FeatureRow(icon: Icons.verified_user, title: 'KYC Level', desc: 'Verified accounts receive higher offline limits.'),
            const _FeatureRow(icon: Icons.shield, title: 'Fraud Prevention', desc: 'Caps offline exposure based on local risk signals.'),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.highlight = false});
  final String label, value;
  final bool highlight;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 14)),
        Text(value, style: TextStyle(
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          fontSize: highlight ? 18 : 14,
          color: highlight ? AppTheme.tngBlueDark : const Color(0xFF1F2937),
        )),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.desc});
  final IconData icon;
  final String title, desc;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.tngBlue.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: AppTheme.tngBlue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
