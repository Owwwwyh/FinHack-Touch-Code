import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/connectivity/connectivity_provider.dart';
import '../../core/connectivity/connectivity_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connectivityServiceProvider);
    final service = ref.read(connectivityServiceProvider.notifier);
    final now = DateTime.now();

    final confidenceText = switch (state.tier) {
      ConnectivityTier.online => 'High confidence',
      ConnectivityTier.stale => 'Moderate confidence',
      ConnectivityTier.offline => 'Low confidence',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Wallet Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectivityBanner(state: state, now: now),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest cached balance',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'RM 245.80',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Safe offline balance (AI): RM 120.00',
                    style: TextStyle(
                      color: Color(0xFF0B57C7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Balance confidence: $confidenceText'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.push(RoutePaths.pay),
                  icon: const Icon(Icons.nfc),
                  label: const Text('Pay Offline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(RoutePaths.receive),
                  icon: const Icon(Icons.call_received),
                  label: const Text('Receive Offline'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phase 1 simulation panel',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('Network available: ${state.hasNetwork ? 'yes' : 'no'}'),
                  Text('Sync failures: ${state.consecutiveSyncFailures}'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: service.markSyncSuccess,
                        child: const Text('Get latest balance'),
                      ),
                      OutlinedButton(
                        onPressed: service.markSyncFailure,
                        child: const Text('Simulate sync failure'),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            service.setNetworkAvailable(!state.hasNetwork),
                        child:
                            Text(state.hasNetwork ? 'Go offline' : 'Go online'),
                      ),
                      OutlinedButton(
                        onPressed: () => service.ageLastSyncBy(
                          const Duration(minutes: 11),
                        ),
                        child: const Text('Age cache by 11 min'),
                      ),
                    ],
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

class _ConnectivityBanner extends StatelessWidget {
  const _ConnectivityBanner({required this.state, required this.now});

  final ConnectivityViewState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bgColor = switch (state.tier) {
      ConnectivityTier.online => const Color(0xFFE8F4FF),
      ConnectivityTier.stale => const Color(0xFFFFF4DD),
      ConnectivityTier.offline => const Color(0xFFFEE2E2),
    };

    final iconColor = switch (state.tier) {
      ConnectivityTier.online => const Color(0xFF0B57C7),
      ConnectivityTier.stale => const Color(0xFFB45309),
      ConnectivityTier.offline => const Color(0xFFB91C1C),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.bannerText(now),
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
