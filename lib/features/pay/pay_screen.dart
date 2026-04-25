// lib/features/pay/pay_screen.dart
//
// Implements wireframes 4.3 (amount entry) and 4.4 (tap in progress).
// docs/02-user-flows.md §4.3, §4.4 / Flow F4

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class PayScreen extends ConsumerStatefulWidget {
  const PayScreen({super.key});
  @override
  ConsumerState<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends ConsumerState<PayScreen> {
  String _amount = '0';

  void _onKey(String k) {
    setState(() {
      if (k == '⌫') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        _amount = _amount == '0' ? k : _amount + k;
        // Limit to 2 decimal places
        final parts = _amount.split('.');
        if (parts.length == 2 && parts[1].length > 2) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      }
    });
  }

  double get _amountValue => double.tryParse(_amount) ?? 0;

  @override
  Widget build(BuildContext context) {
    final wallet    = ref.watch(walletProvider);
    final tapState  = ref.watch(payScreenProvider);
    final safeLimit = wallet.safeOfflineMyr;
    final overLimit = _amountValue > safeLimit || _amountValue <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay via NFC'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: tapState == NfcTapState.detecting || tapState == NfcTapState.transferring
          ? _TapInProgress(tapState: tapState, amount: _amount)
          : tapState == NfcTapState.done
              ? _TapDone(amount: _amount, onDone: () {
                  ref.read(payScreenProvider.notifier).reset();
                  context.go('/home');
                })
              : _AmountEntry(
                  amount: _amount,
                  safeLimit: safeLimit,
                  overLimit: overLimit,
                  onKey: _onKey,
                  onPay: overLimit ? null : () => _startNfc(context, ref),
                ),
    );
  }

  void _startNfc(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(payScreenProvider.notifier);
    notifier.detecting();
    // In Phase 3 this triggers nfc_session.dart.
    // For Phase 2 demo, simulate with a delay.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        notifier.transferring();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            notifier.done();
            ref.read(walletProvider.notifier).decrementSafeBalance(_amountValue);
            ref.read(pendingCountProvider.notifier).state++;
          }
        });
      }
    });
  }
}

// ─── Amount entry sub-widget ──────────────────────────────────────────────────

class _AmountEntry extends StatelessWidget {
  const _AmountEntry({
    required this.amount, required this.safeLimit, required this.overLimit,
    required this.onKey, required this.onPay,
  });
  final String amount;
  final double safeLimit;
  final bool overLimit;
  final void Function(String) onKey;
  final VoidCallback? onPay;

  static const _keys = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['.','0','⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          // Amount display
          Text(
            'RM $amount',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 52, fontWeight: FontWeight.w800,
              color: overLimit ? Colors.red.shade400 : AppTheme.tngBlueDark,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: overLimit && amount != '0'
              ? Text(
                  'Exceeds safe limit (RM ${safeLimit.toStringAsFixed(2)})',
                  key: const ValueKey('over'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                )
              : Text(
                  'Safe offline limit: RM ${safeLimit.toStringAsFixed(2)}',
                  key: const ValueKey('ok'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.offlineGrey, fontSize: 13),
                ),
          ),
          const SizedBox(height: 32),
          // Numpad
          for (final row in _keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) => _NumKey(label: k, onTap: () => onKey(k))).toList(),
              ),
            ),
          const SizedBox(height: 32),
          // NFC tap button
          FilledButton.icon(
            onPressed: onPay,
            icon: const Icon(Icons.nfc),
            label: const Text('Hold near receiver'),
            style: FilledButton.styleFrom(
              backgroundColor: onPay != null ? AppTheme.tngBlue : AppTheme.offlineGrey,
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: 64, height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF3F4F6),
          ),
          child: Text(label,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
        ),
      ),
    );
  }
}

// ─── Tap in progress ──────────────────────────────────────────────────────────

class _TapInProgress extends StatelessWidget {
  const _TapInProgress({required this.tapState, required this.amount});
  final NfcTapState tapState;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing NFC animation
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.1),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tngBlue.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.nfc, color: AppTheme.tngBlue, size: 48),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tapState == NfcTapState.detecting ? 'Hold near receiver...' : 'Transferring token...',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('RM $amount',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.tngBlueDark)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

// ─── Done / receipt ───────────────────────────────────────────────────────────

class _TapDone extends StatelessWidget {
  const _TapDone({required this.amount, required this.onDone});
  final String amount;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: AppTheme.settled, size: 80),
            const SizedBox(height: 20),
            Text('Sent RM $amount',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Token signed & queued\nWill settle when online',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.offlineGrey, fontSize: 15),
            ),
            const SizedBox(height: 32),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}
