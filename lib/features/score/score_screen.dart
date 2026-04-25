import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class ScoreScreen extends ConsumerWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Offline Limit'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(walletProvider.notifier).refreshAIScore(),
          ),
        ],
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
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.tngBlue, size: 48),
                  const SizedBox(height: 16),
                  const Text('AI-Powered Security', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  const Text(
                    'Your safe offline limit is dynamically calculated by our on-device AI to protect your funds if your phone is lost while offline.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.offlineGrey, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  _StatRow(label: 'Current Limit', value: 'RM ${wallet.safeOfflineMyr.toStringAsFixed(2)}', highlight: true),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  _StatRow(label: 'Risk Score', value: wallet.riskScore, color: _getRiskColor(wallet.riskScore)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  _StatRow(label: 'Total Available Balance', value: 'RM ${wallet.balanceMyr.toStringAsFixed(2)}'),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
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

  Color _getRiskColor(String score) {
    switch (score) {
      case 'LOW': return Colors.green;
      case 'MEDIUM': return Colors.orange;
      case 'HIGH': return Colors.red;
      default: return AppTheme.offlineGrey;
    }
  }
}
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.highlight = false, this.color});
  final String label, value;
  final bool highlight;
  final Color? color;
  
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 14)),
        Text(value, style: TextStyle(
          fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
          fontSize: highlight ? 18 : 14,
          color: color ?? (highlight ? AppTheme.tngBlueDark : const Color(0xFF1F2937)),
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
