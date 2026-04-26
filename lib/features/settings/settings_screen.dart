import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/crypto/device_identity_service.dart';
import '../../domain/services/credit_scorer.dart';
import '../home/offline/offline_score_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(baseOfflineScoreProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(label: 'Device Info'),
          _DeviceInfoCard(score: score),
          const SizedBox(height: 16),
          const _SectionHeader(label: 'Security'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Rotate signing key'),
                  subtitle: const Text('Generate a new Ed25519 device key'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Key rotation not available in demo'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionHeader(label: 'Account'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFDC2626)),
              title: const Text(
                'Sign out',
                style: TextStyle(color: Color(0xFFDC2626)),
              ),
              onTap: () => context.go(RoutePaths.onboarding),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({required this.score});
  final CreditScoreDecision score;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(label: 'Model version', value: score.modelVersion),
            const SizedBox(height: 10),
            _InfoRow(label: 'Policy version', value: score.policyVersion),
            const SizedBox(height: 10),
            FutureBuilder<DeviceIdentity>(
              future: NativeOfflineSigningService().ensureIdentity(),
              builder: (context, snapshot) {
                final kid = snapshot.data?.kid ?? '—';
                final display = kid.length > 16
                    ? '${kid.substring(0, 8)}…${kid.substring(kid.length - 6)}'
                    : kid;
                return _InfoRow(label: 'Device key ID', value: display);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
