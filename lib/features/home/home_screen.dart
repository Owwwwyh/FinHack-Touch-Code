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

    ref.listen(
      offlinePaymentControllerProvider.select((state) => state.settleMessage),
      (previous, next) {
        if (next != null && next.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next)),
          );
          ref
              .read(offlinePaymentControllerProvider.notifier)
              .clearSettleMessage();
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go(RoutePaths.settings),
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
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: connectivity.hasNetwork
                        ? connectivityService.markSyncSuccess
                        : null,
                    child: Text(
                      connectivity.hasNetwork
                          ? 'Get latest balance'
                          : 'Reconnect to refresh',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.history),
                    icon: const Icon(Icons.history),
                    label: const Text('History'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PendingTokensList(
              payments: payments,
              hasNetwork: connectivity.hasNetwork,
              onSettle: connectivity.hasNetwork
                  ? () => ref
                      .read(offlinePaymentControllerProvider.notifier)
                      .settleOutbox()
                  : null,
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

class _PendingTokensList extends StatelessWidget {
  const _PendingTokensList({
    required this.payments,
    required this.hasNetwork,
    required this.onSettle,
  });

  final OfflinePaymentState payments;
  final bool hasNetwork;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    final pendingOutbox = payments.outbox
        .where((t) =>
            t.status != OfflineTransferStatus.settled &&
            t.status != OfflineTransferStatus.rejected)
        .toList();
    final pendingInbox = payments.inbox
        .where((t) =>
            t.status != OfflineTransferStatus.settled &&
            t.status != OfflineTransferStatus.rejected)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Pending settlement',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${pendingOutbox.length + pendingInbox.length} token(s)',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (pendingOutbox.isEmpty && pendingInbox.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'No pending tokens',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ] else ...[
              const SizedBox(height: 12),
              ...pendingOutbox.map((t) => _PendingRow(
                    transfer: t,
                    sent: true,
                    onSettle: onSettle,
                  )),
              ...pendingInbox.map((t) => _PendingRow(
                    transfer: t,
                    sent: false,
                    onSettle: onSettle,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.transfer,
    required this.sent,
    required this.onSettle,
  });

  final OfflineTransfer transfer;
  final bool sent;
  final VoidCallback? onSettle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            sent ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: sent ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.counterpartyLabel ?? (sent ? 'Sent' : 'Received'),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  transfer.amountLabel,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onSettle,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Settle now', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
