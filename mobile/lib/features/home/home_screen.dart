import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/connectivity/connectivity_service.dart';
import '../../core/di/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStateProvider);
    final isOffline = connectivity == ConnectivityState.offline;
    final isStale = connectivity == ConnectivityState.stale;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Status header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
              color: isOffline
                  ? const Color(0xFF6B7280)
                  : isStale
                      ? const Color(0xFF9E9E9E)
                      : const Color(0xFF004A9D),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 19,
                        backgroundColor: Colors.white,
                        child: Text('FZ', style: TextStyle(color: Color(0xFF004A9D), fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('TNG Wallet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () => context.go('/score'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        onPressed: () => context.go('/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Connectivity indicator
                  _ConnectivityBanner(connectivity: connectivity),
                  const SizedBox(height: 14),
                  // Balance display
                  if (!isOffline) ...[
                    const Text('RM 248.50', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 42, height: 1)),
                    const SizedBox(height: 4),
                    Text(
                      connectivity == ConnectivityState.online ? 'available balance' : 'cached balance',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Safe offline balance - always shown
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF4ADE80), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Safe offline:  RM 120.00',
                        style: TextStyle(
                          color: isOffline ? Colors.white : Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isOffline)
                        GestureDetector(
                          onTap: () => context.go('/score'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('AI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(icon: Icons.nfc, label: 'PAY', onTap: () => context.go('/pay'), color: const Color(0xFF0061A8)),
                  _ActionButton(icon: Icons.nfc, label: 'RECEIVE', onTap: () => context.go('/receive'), color: const Color(0xFF16A34A)),
                  _ActionButton(icon: Icons.history, label: 'HISTORY', onTap: () => context.go('/history'), color: const Color(0xFF6B7280)),
                  _ActionButton(icon: Icons.pending_actions, label: 'PENDING', onTap: () => context.go('/pending'), color: const Color(0xFFFFA000)),
                ],
              ),
            ),
            const Divider(height: 1),
            // Recent transactions
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Text('Recent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ),
            _TransactionTile(label: 'Aida Stall', amount: '-RM 8.50', isSettled: true),
            _TransactionTile(label: 'Top-up', amount: '+RM 50.00', isSettled: true),
            _TransactionTile(label: 'Faiz Ride', amount: '-RM 12.00', isSettled: false),
          ],
        ),
      ),
    );
  }
}

class _ConnectivityBanner extends StatelessWidget {
  final ConnectivityState connectivity;
  const _ConnectivityBanner({required this.connectivity});

  @override
  Widget build(BuildContext context) {
    switch (connectivity) {
      case ConnectivityState.online:
        return Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('Online  ·  synced 2 sec ago', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          ],
        );
      case ConnectivityState.stale:
        return Row(
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFA000), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            const Text('Stale  ·  last sync 14 min', style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        );
      case ConnectivityState.offline:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF9E9E9E), shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('Offline  ·  last sync 14 min', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Limited mode', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionButton({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final String label;
  final String amount;
  final bool isSettled;

  const _TransactionTile({required this.label, required this.amount, required this.isSettled});

  @override
  Widget build(BuildContext context) {
    final isIn = amount.startsWith('+');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIn ? const Color(0xFFF0FDF4) : const Color(0xFFEEF5FF),
        child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, color: isIn ? const Color(0xFF16A34A) : const Color(0xFF0061A8)),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(isSettled ? 'Settled' : 'Pending', style: TextStyle(color: isSettled ? const Color(0xFF16A34A) : const Color(0xFFFFA000), fontSize: 12)),
      trailing: Text(amount, style: TextStyle(fontWeight: FontWeight.bold, color: isIn ? const Color(0xFF16A34A) : Colors.black87)),
    );
  }
}
