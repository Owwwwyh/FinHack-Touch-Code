import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart' show RoutePaths, DemoRole;
import '../../core/connectivity/connectivity_provider.dart';
import '../../core/connectivity/connectivity_state.dart';
import '../../domain/models/offline_transfer.dart';
import 'offline/offline_profile.dart';
import 'offline/offline_score_provider.dart';
import '../../domain/services/credit_scorer.dart' show CreditScoreDecision;
import 'offline/offline_banner.dart';
import 'offline/nfc_pay_sheet.dart';
import 'offline/buyer_nfc_sheet.dart';
import 'offline/token_receipt.dart';
import 'offline/pending_queue.dart' show PendingQueue, PendingTxn;
import 'widgets/balance_card.dart';
import 'widgets/quick_actions.dart';
import 'widgets/promo_banner.dart';
import 'widgets/services_grid.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/tng_top_bar.dart';
import 'widgets/tng_bottom_nav.dart';
import '../offline/offline_payment_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _activeTab = 0;
  OfflineToken? _receipt;
  late DemoRole _role;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    _role = extra is DemoRole ? extra : DemoRole.seller;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityServiceProvider);
    final connectivityService = ref.read(connectivityServiceProvider.notifier);
    final payments = ref.watch(offlinePaymentControllerProvider);
    final score = ref.watch(baseOfflineScoreProvider);
    final now = DateTime.now();

    final pendingOutgoingCents = _pendingOutgoingCents(payments.outbox);
    final availableSafeBalanceCents = score.availableSafeBalanceCents(
      pendingOutgoingCents: pendingOutgoingCents,
    );
    final isOffline = connectivity.tier != ConnectivityTier.online;

    ref.listen(
      offlinePaymentControllerProvider.select((s) => s.errorMessage),
      (_, next) {
        if (next != null && next.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
          ref.read(offlinePaymentControllerProvider.notifier).dismissError();
        }
      },
    );

    ref.listen(
      offlinePaymentControllerProvider.select((s) => s.settleMessage),
      (_, next) {
        if (next != null && next.isNotEmpty && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next)));
          ref.read(offlinePaymentControllerProvider.notifier).clearSettleMessage();
        }
      },
    );

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: Column(
            children: [
              // ── Blue header ──────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0066FF), Color(0xFF0057E0)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      TngTopBar(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Row(
                          children: [
                            Text(
                              isOffline ? 'Offline Mode' : 'Touch \'n Go eWallet',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                if (isOffline) {
                                  final pendingCount = payments.outbox
                                      .where((t) =>
                                          t.status != OfflineTransferStatus.settled &&
                                          t.status != OfflineTransferStatus.rejected)
                                      .length;
                                  if (pendingCount > 0) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Syncing $pendingCount transaction(s)...'),
                                      ),
                                    );
                                  }
                                  connectivityService.setNetworkAvailable(true);
                                  connectivityService.markSyncSuccess();
                                } else {
                                  connectivityService.setNetworkAvailable(false);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isOffline
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOffline ? Icons.wifi_off : Icons.wifi,
                                      size: 13,
                                      color: isOffline
                                          ? const Color(0xFF2563EB)
                                          : Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isOffline ? 'Sync & Go Online' : 'Online · switch',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOffline
                                            ? const Color(0xFF2563EB)
                                            : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Scrollable body ──────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    if (connectivity.hasNetwork) {
                      connectivityService.markSyncSuccess();
                    }
                  },
                  child: isOffline
                      ? _OfflineBody(
                          score: score,
                          availableSafeBalanceCents: availableSafeBalanceCents,
                          pendingOutgoingCents: pendingOutgoingCents,
                          connectivity: connectivity,
                          payments: payments,
                          now: now,
                          role: _role,
                          onNfcTap: () => _role == DemoRole.seller
                              ? _openSellerSheet(
                                  context, availableSafeBalanceCents / 100)
                              : _openBuyerSheet(
                                  context, availableSafeBalanceCents / 100),
                          onRequestPayment: () => context.go(RoutePaths.request),
                          onHistory: () => context.go(RoutePaths.history),
                          onRefresh: () {
                            if (connectivity.hasNetwork) {
                              connectivityService.markSyncSuccess();
                            }
                          },
                        )
                      : _OnlineBody(
                          activeTab: _activeTab,
                          onRequestPayment: () => context.go(RoutePaths.request),
                          onHistory: () => context.go(RoutePaths.history),
                          onSettings: () => context.go(RoutePaths.settings),
                        ),
                ),
              ),

              // ── Bottom nav ────────────────────────────────────────────────
              TngBottomNav(
                activeTab: _activeTab,
                onTabChanged: (i) => setState(() => _activeTab = i),
              ),
            ],
          ),
        ),

        // ── Token receipt overlay ─────────────────────────────────────────
        if (_receipt != null)
          TokenReceiptScreen(
            token: _receipt!,
            onDone: () => setState(() => _receipt = null),
          ),
      ],
    );
  }

  Future<void> _openSellerSheet(BuildContext context, double balance) async {
    final token = await showModalBottomSheet<OfflineToken>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: NfcPaySheet(balance: balance),
      ),
    );
    if (token != null && mounted) {
      setState(() => _receipt = token);
    }
  }

  Future<void> _openBuyerSheet(BuildContext context, double balance) async {
    final token = await showModalBottomSheet<OfflineToken>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: BuyerNfcSheet(
          amount: 5.00,
          merchantName: 'Aida Rahman',
          balance: balance,
        ),
      ),
    );
    if (token != null && mounted) {
      setState(() => _receipt = token);
    }
  }
}

// ─── Offline body ─────────────────────────────────────────────────────────────

class _OfflineBody extends StatelessWidget {
  const _OfflineBody({
    required this.score,
    required this.availableSafeBalanceCents,
    required this.pendingOutgoingCents,
    required this.connectivity,
    required this.payments,
    required this.now,
    required this.role,
    required this.onNfcTap,
    required this.onRequestPayment,
    required this.onHistory,
    required this.onRefresh,
  });

  final CreditScoreDecision score;
  final int availableSafeBalanceCents;
  final int pendingOutgoingCents;
  final ConnectivityViewState connectivity;
  final OfflinePaymentState payments;
  final DateTime now;
  final DemoRole role;
  final VoidCallback onNfcTap;
  final VoidCallback onRequestPayment;
  final VoidCallback onHistory;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final pendingItems = payments.outbox
        .where((t) =>
            t.status != OfflineTransferStatus.settled &&
            t.status != OfflineTransferStatus.rejected)
        .toList();

    final isBuyer = role == DemoRole.buyer;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        OfflineBanner(pendingCount: pendingItems.length),
        OfflineProfile(
          offlineCap: score.hardCapCents / 100,
          aiSafeBalance: availableSafeBalanceCents / 100,
          lastSync: '${connectivity.syncAgeMinutes(now) ?? 0} min ago',
          onRefresh: onRefresh,
          policyVersion: score.policyVersion,
          modelVersion: score.modelVersion,
          confidence: score.confidence,
          pendingOutgoingCents: pendingOutgoingCents,
          lifetimeTransactionCount: score.lifetimeTransactionCount,
          isAiEligible: score.isAiEligible,
          modeLabel: 'On-device estimate',
          drivers: score.panelDrivers(pendingOutgoingCents: pendingOutgoingCents),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: onNfcTap,
            icon: Icon(isBuyer ? Icons.payment : Icons.nfc, size: 24),
            label: Text(
              isBuyer ? 'Pay' : 'Request',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // History — same width, centered
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
              ),
            ),
          ),
        ),
        if (pendingItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PendingQueue(
              items: pendingItems
                  .take(3)
                  .map((t) => PendingTxn(
                        id: t.txId,
                        merchant: t.counterpartyLabel ?? 'Pending',
                        amount: t.amountCents / 100,
                        time: 'Pending',
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Online body ──────────────────────────────────────────────────────────────

class _OnlineBody extends StatelessWidget {
  const _OnlineBody({
    required this.activeTab,
    required this.onRequestPayment,
    required this.onHistory,
    required this.onSettings,
  });

  final int activeTab;
  final VoidCallback onRequestPayment;
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: const [
        SizedBox(height: 8),
        BalanceCard(),
        QuickActions(),
        PromoBanner(),
        ServicesGrid(),
        RecentTransactions(),
      ],
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

int _pendingOutgoingCents(List<OfflineTransfer> outbox) {
  return outbox
      .where((t) =>
          t.status != OfflineTransferStatus.rejected &&
          t.status != OfflineTransferStatus.settled)
      .fold<int>(0, (total, t) => total + t.amountCents);
}
