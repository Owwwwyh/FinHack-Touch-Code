// lib/features/home/home_screen.dart
//
// Implements wireframes 4.1 (online) and 4.2 (offline) from docs/02-user-flows.md.
// Key requirements:
//   - Offline indicator ABOVE balance card
//   - Always shows BOTH synced balance AND safe-offline balance
//   - Offline state: muted/grey palette (not red — it's a feature)
//   - Pending token count badge

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/connectivity/connectivity_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet  = ref.watch(walletProvider);
    final connState = ref.watch(connectivityServiceProvider);
    final isOffline = connState.state == ConnectivityState.offline;
    final pending = ref.watch(pendingCountProvider);

    final headerColor = isOffline ? AppTheme.offlineGrey : AppTheme.tngBlueDark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Header + balance card ──────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 230,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                color: headerColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top row ─────────────────────────────────────────────
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Text('JM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        const Text('eWallet Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.notifications_none, color: Colors.white),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                          onPressed: () => context.go('/settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // ── Connectivity status pill ─────────────────────────────
                    _StatusPill(connState: connState),
                    const SizedBox(height: 10),
                    // ── Balance ──────────────────────────────────────────────
                    Text(
                      'RM ${wallet.balanceMyr.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 42,
                        fontWeight: FontWeight.w800, height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('available balance',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),

              // ── Floating action card ──────────────────────────────────────
              Positioned(
                left: 16, right: 16, bottom: -72,
                child: _ActionCard(wallet: wallet, isOffline: isOffline, pending: pending),
              ),
            ],
          ),

          const SizedBox(height: 86),

          // ── Safe offline balance info ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SafeOfflineCard(
              safeOffline: wallet.safeOfflineMyr,
              balance: wallet.balanceMyr,
              isOffline: isOffline,
              onTapInfo: () => context.go('/score'),
            ),
          ),

          const SizedBox(height: 14),

          // ── Offline reconnect hint ────────────────────────────────────────
          if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReconnectBanner(pending: pending),
            ),

          // ── Recent transactions header ─────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text('Recent', style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1F2937))),
          ),

          // ── Recent items (demo data) ──────────────────────────────────────
          ..._demoTransactions.map((t) => _TxTile(
            label: t.$1, amount: t.$2, isIn: t.$3, status: t.$4)),
        ],
      ),
    );
  }

  static const _demoTransactions = [
    ('Aida Stall (NFC)', '−RM 8.50', false, 'settled'),
    ('Top-up via FPX', '+RM 50.00', true, 'settled'),
    ('Grab Rider Pay', '−RM 12.00', false, 'pending'),
  ];
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.connState});
  final WalletConnectivity connState;

  @override
  Widget build(BuildContext context) {
    final isOffline = connState.state == ConnectivityState.offline;
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOffline ? Colors.white54 : Colors.greenAccent,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          connState.statusLabel,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (isOffline) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Limited mode',
              style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
        ],
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.wallet, required this.isOffline, required this.pending});
  final dynamic wallet;
  final bool isOffline;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionBtn(
              icon: Icons.nfc,
              label: 'Pay',
              color: AppTheme.tngBlue,
              onTap: () => context.go('/pay'),
            ),
            _ActionBtn(
              icon: Icons.call_received,
              label: 'Receive',
              color: AppTheme.settled,
              onTap: () => context.go('/receive'),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ActionBtn(
                  icon: Icons.pending_actions_outlined,
                  label: 'Pending',
                  color: AppTheme.pending,
                  onTap: () => context.go('/pending'),
                ),
                if (pending > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Colors.red),
                      alignment: Alignment.center,
                      child: Text('$pending',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            _ActionBtn(
              icon: Icons.history,
              label: 'History',
              color: AppTheme.offlineGrey,
              onTap: () => context.go('/history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _SafeOfflineCard extends StatelessWidget {
  const _SafeOfflineCard({
    required this.safeOffline, required this.balance,
    required this.isOffline, required this.onTapInfo,
  });
  final double safeOffline, balance;
  final bool isOffline;
  final VoidCallback onTapInfo;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                        color: isOffline ? AppTheme.offlineGrey : AppTheme.tngBlue, size: 18),
                      const SizedBox(width: 6),
                      Text('Safe offline limit',
                        style: TextStyle(
                          color: isOffline ? AppTheme.offlineGrey : AppTheme.tngBlueDark,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onTapInfo,
                        child: Icon(Icons.info_outline, size: 14,
                          color: isOffline ? AppTheme.offlineGrey : AppTheme.tngBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${safeOffline.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: isOffline ? AppTheme.offlineGrey : AppTheme.tngBlueDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('of RM ${balance.toStringAsFixed(2)} available',
                    style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOffline ? AppTheme.offlineGrey.withValues(alpha: 0.1) : AppTheme.tngBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(isOffline ? 'AI offline' : '✓ AI',
                style: TextStyle(
                  color: isOffline ? AppTheme.offlineGrey : AppTheme.tngBlue,
                  fontSize: 12, fontWeight: FontWeight.w700,
                )),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.pending});
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.offlineBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.offlineGrey.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.offlineGrey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending > 0
                    ? '$pending pending token${pending > 1 ? "s" : ""} · will settle when online'
                    : 'No pending tokens',
                  style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Reconnect',
              style: TextStyle(color: AppTheme.tngBlue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.label, required this.amount, required this.isIn, required this.status});
  final String label, amount, status;
  final bool isIn;

  @override
  Widget build(BuildContext context) {
    final color = isIn ? AppTheme.settled : const Color(0xFF1F2937);
    final isPending = status == 'pending';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIn
          ? AppTheme.settled.withValues(alpha: 0.12)
          : AppTheme.tngBlue.withValues(alpha: 0.12),
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.nfc,
          color: isIn ? AppTheme.settled : AppTheme.tngBlue, size: 18,
        ),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(isPending ? '⏳ Pending settlement' : '✓ Settled',
        style: TextStyle(
          fontSize: 12,
          color: isPending ? AppTheme.pending : AppTheme.offlineGrey,
        )),
      trailing: Text(amount,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
    );
  }
}
