import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/connectivity/connectivity_provider.dart';
import '../../core/connectivity/connectivity_state.dart';
import '../offline/offline_payment_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityServiceProvider);
    final connectivityService = ref.read(connectivityServiceProvider.notifier);
    final payments = ref.watch(offlinePaymentControllerProvider);

    ref.listen(
      offlinePaymentControllerProvider.select((state) => state.incomingRequest),
      (previous, next) {
        if (next != null && context.mounted) {
          context.go(RoutePaths.payConfirm);
        }
      },
    );

    ref.listen(
      offlinePaymentControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next != null && next.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
          ref.read(offlinePaymentControllerProvider.notifier).dismissError();
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Wallet Home'),
        actions: [
          TextButton(
            onPressed: () {
              if (connectivity.hasNetwork) {
                connectivityService.setNetworkAvailable(false);
                connectivityService.ageLastSyncBy(const Duration(minutes: 12));
              } else {
                connectivityService.setNetworkAvailable(true);
                connectivityService.markSyncSuccess();
              }
            },
            child: Text(
              connectivity.hasNetwork ? 'Go offline' : 'Go online',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _StatusBanner(state: connectivity),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Latest cached balance',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'RM 248.50',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12),
                  Text('Safe offline balance'),
                  SizedBox(height: 4),
                  Text(
                    'RM 120.00',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(RoutePaths.request),
                  icon: const Icon(Icons.point_of_sale),
                  label: const Text('Request Payment'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.receive),
                  icon: const Icon(Icons.inbox_outlined),
                  label: const Text('Receive Inbox'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: connectivityService.markSyncSuccess,
            child: const Text('Get latest balance'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pending settlement',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _MetricRow(
                    label: 'Merchant requests waiting',
                    value: payments.outgoingRequest == null ? '0' : '1',
                  ),
                  _MetricRow(
                    label: 'Outbox tokens',
                    value: payments.outbox.length.toString(),
                  ),
                  _MetricRow(
                    label: 'Inbox tokens',
                    value: payments.inbox.length.toString(),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final ConnectivityViewState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOffline = state.tier == ConnectivityTier.offline;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOffline ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOffline ? const Color(0xFFF97316) : const Color(0xFF22C55E),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.wifi,
              color:
                  isOffline ? const Color(0xFFEA580C) : const Color(0xFF15803D),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.bannerText(now),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
