import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_provider.dart';
import 'offline/how_it_works.dart';
import 'offline/nfc_pay_sheet.dart';
import 'offline/offline_banner.dart';
import 'offline/offline_bottom_bar.dart';
import 'offline/offline_profile.dart';
import 'offline/pending_queue.dart';
import 'offline/token_receipt.dart';
import 'widgets/balance_card.dart';
import 'widgets/promo_banner.dart';
import 'widgets/quick_actions.dart';
import 'widgets/recent_transactions.dart';
import 'widgets/services_grid.dart';
import 'widgets/tng_bottom_nav.dart';
import 'widgets/tng_status_bar.dart';
import 'widgets/tng_top_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _initialOfflineCap = 250.0;

  int _activeTab = 0;
  String _offlineView = 'home';
  double _offlineCap = _initialOfflineCap;
  double _aiSafeBalance = 187.4;
  String _lastSync = '8 min ago';
  List<PendingTxn> _pending = const [];
  OfflineToken? _receipt;

  void _handlePaid(OfflineToken token) {
    setState(() {
      _offlineCap = (_offlineCap - token.amount).clamp(0, double.infinity);
      _aiSafeBalance = (_aiSafeBalance - token.amount).clamp(0, double.infinity);
      _pending = [
        PendingTxn(id: token.id, merchant: token.merchant, amount: token.amount, time: 'Just now'),
        ..._pending,
      ];
      _receipt = token;
    });
  }

  void _refreshAi() {
    setState(() {
      _lastSync = 'just now';
      _aiSafeBalance = 150 + (87.4 * (DateTime.now().millisecond / 999));
    });
    _showSnack('AI safe balance refreshed', color: const Color(0xFF059669));
  }

  void _goOnline() {
    final service = ref.read(connectivityServiceProvider.notifier);
    if (_pending.isNotEmpty) {
      _showSnack('Syncing ${_pending.length} transaction${_pending.length > 1 ? 's' : ''}…');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _pending = const []);
        service.setNetworkAvailable(true);
        service.markSyncSuccess();
        _showSnack('All transactions synced', color: const Color(0xFF059669));
      });
    } else {
      service.setNetworkAvailable(true);
      service.markSyncSuccess();
    }
  }

  void _showSnack(String msg, {Color color = const Color(0xFF1E293B)}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openNfcPay() async {
    final token = await showModalBottomSheet<OfflineToken>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: NfcPaySheet(balance: _offlineCap),
      ),
    );
    if (token != null) _handlePaid(token);
  }

  @override
  Widget build(BuildContext context) {
    final connState = ref.watch(connectivityServiceProvider);
    final connService = ref.read(connectivityServiceProvider.notifier);
    final isOnline = connState.hasNetwork;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(isOnline, connService),
              Expanded(
                child: isOnline ? _onlineContent() : _offlineContent(),
              ),
              if (isOnline)
                TngBottomNav(activeTab: _activeTab, onTabChanged: (t) => setState(() => _activeTab = t))
              else
                OfflineBottomBar(
                  onNfcTap: _openNfcPay,
                  currentView: _offlineView,
                  onViewChanged: (v) => setState(() => _offlineView = v),
                ),
            ],
          ),
          if (_receipt != null)
            TokenReceiptScreen(token: _receipt!, onDone: () => setState(() => _receipt = null)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isOnline, dynamic connService) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0066FF), Color(0xFF0057E0)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const TngStatusBar(),
            if (isOnline) ...[
              const TngTopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => connService.setNetworkAvailable(false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text('Online · switch offline',
                              style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Touch 'n Go eWallet",
                            style: TextStyle(color: Colors.white70, fontSize: 11)),
                        Text('Offline Mode',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _goOnline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off, color: Color(0xFF2563EB), size: 13),
                            const SizedBox(width: 5),
                            Text(
                              _pending.isNotEmpty ? 'Sync & Go Online' : 'Go Online',
                              style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _onlineContent() => ListView(
        children: const [
          SizedBox(height: 4),
          BalanceCard(),
          QuickActions(),
          PromoBanner(),
          ServicesGrid(),
          RecentTransactions(),
        ],
      );

  Widget _offlineContent() => ListView(
        children: [
          OfflineBanner(pendingCount: _pending.length),
          if (_offlineView == 'home') ...[
            OfflineProfile(
              offlineCap: _offlineCap,
              aiSafeBalance: _aiSafeBalance,
              lastSync: _lastSync,
              onRefresh: _refreshAi,
            ),
            HowItWorks(cap: _initialOfflineCap),
            PendingQueue(items: _pending.take(3).toList()),
          ] else
            PendingQueue(items: _pending),
        ],
      );
}
