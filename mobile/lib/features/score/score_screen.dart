import 'package:flutter/material.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your safe offline balance')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Big number
          const Center(
            child: Column(
              children: [
                Text('RM 120.00', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: Color(0xFF0061A8))),
                SizedBox(height: 4),
                Text('out of RM 248.50 available', style: TextStyle(color: Color(0xFF6B7280), fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // How we calculate
          const Text('How we calculate this:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          _FeatureRow(icon: Icons.receipt_long, text: 'Your usual spend'),
          _FeatureRow(icon: Icons.sync, text: 'How often you reload'),
          _FeatureRow(icon: Icons.schedule, text: 'Time since last sync'),
          _FeatureRow(icon: Icons.history, text: 'Your transaction history'),
          const SizedBox(height: 24),
          // How to improve
          const Text('To raise this limit:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 16),
          _ImproveRow(text: 'Reload more regularly'),
          _ImproveRow(text: 'Complete KYC tier 2'),
          const SizedBox(height: 32),
          // Model version
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Color(0xFF6B7280)),
                SizedBox(width: 8),
                Text('Model version: 2026-04-22 v3', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF0061A8)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _ImproveRow extends StatelessWidget {
  final String text;
  const _ImproveRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.arrow_right, size: 20, color: Color(0xFF0061A8)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}
