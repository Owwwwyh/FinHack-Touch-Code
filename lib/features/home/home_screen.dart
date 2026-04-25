import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../core/connectivity/connectivity_provider.dart';
import '../../core/connectivity/connectivity_state.dart';
import '../../domain/models/offline_transfer.dart';
import 'offline/offline_profile.dart';
import 'offline/offline_score_provider.dart';
import '../offline/offline_payment_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityServiceProvider);
    final connectivityService = ref.read(connectivityServiceProvider.notifier);
    final payments = ref.watch(offlinePaymentControllerProvider);
    final score = ref.watch(baseOfflineScoreProvider);
    final now = DateTime.now();
    final pendingOutgoingCents = _pendingOutgoingCents(payments.outbox);
    final availableSafeBalanceCents = score.availableSafeBalanceCents(
      pendingOutgoingCents: pendingOutgoingCents,
    );
    final showSafeBalance = connectivity.tier != ConnectivityTier.online;
    final primaryLabel =
        showSafeBalance ? 'Safe offline balance' : 'Latest cached balance';
    final primaryAmountCents =
        showSafeBalance ? availableSafeBalanceCents : score.cachedBalanceCents;
    final secondaryLabel =
        showSafeBalance ? 'Cached wallet balance' : 'Safe offline balance';
    final secondaryAmountCents =
        showSafeBalance ? score.cachedBalanceCents : availableSafeBalanceCents;

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
      body: RefreshIndicator(
        onRefresh: () async {
          if (connectivity.hasNetwork) {
            connectivityService.markSyncSuccess();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _StatusBanner(state: connectivity),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatMyr(primaryAmountCents),
                      key: const ValueKey('home-primary-balance'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$secondaryLabel: ${_formatMyr(secondaryAmountCents)}',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Policy ${score.policyVersion} · model ${score.modelVersion}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                    if (pendingOutgoingCents > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_formatMyr(pendingOutgoingCents)} reserved for pending settlement.',
                        style: const TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            OfflineProfile(
              offlineCap: score.hardCapCents / 100,
              aiSafeBalance: availableSafeBalanceCents / 100,
              lastSync: '${connectivity.syncAgeMinutes(now) ?? 0} min ago',
              onRefresh: () {
                if (connectivity.hasNetwork) {
                  connectivityService.markSyncSuccess();
                }
              },
              policyVersion: score.policyVersion,
              modelVersion: score.modelVersion,
              confidence: score.confidence,
              pendingOutgoingCents: pendingOutgoingCents,
              lifetimeTransactionCount: score.lifetimeTransactionCount,
              isAiEligible: score.isAiEligible,
              modeLabel:
                  showSafeBalance ? 'On-device estimate' : 'Server-aligned',
              drivers: score.panelDrivers(
                pendingOutgoingCents: pendingOutgoingCents,
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
              onPressed: connectivity.hasNetwork
                  ? connectivityService.markSyncSuccess
                  : null,
              child: Text(
                connectivity.hasNetwork
                    ? 'Get latest balance'
                    : 'Reconnect to refresh',
              ),
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
    final isStale = state.tier == ConnectivityTier.stale;
    final backgroundColor = isOffline
        ? const Color(0xFFFFF7ED)
        : isStale
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFF0FDF4);
    final borderColor = isOffline
        ? const Color(0xFFF97316)
        : isStale
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
    final iconColor = isOffline
        ? const Color(0xFFEA580C)
        : isStale
            ? const Color(0xFFD97706)
            : const Color(0xFF15803D);
    final icon = isOffline
        ? Icons.wifi_off
        : isStale
            ? Icons.sync_problem
            : Icons.wifi;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
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

int _pendingOutgoingCents(List<OfflineTransfer> outbox) {
  return outbox
      .where(
        (transfer) =>
            transfer.status != OfflineTransferStatus.rejected &&
            transfer.status != OfflineTransferStatus.settled,
      )
      .fold<int>(
        0,
        (total, transfer) => total + transfer.amountCents,
      );
}

String _formatMyr(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'RM $whole.$fraction';
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
