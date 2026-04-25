// lib/features/pay/pay_screen.dart
//
// UPDATED: Sender side — "Tap receiver phone" and show feedback.
// No amount entry here; amount is entered by the receiver.

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
  @override
  void initState() {
    super.initState();
    // Auto-start NFC detection for sender
    WidgetsBinding.instance.addPostFrameCallback((_) => _startNfc(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final tapState = ref.watch(payScreenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: tapState == NfcTapState.done
          ? _PayDone(onDone: () {
              ref.read(payScreenProvider.notifier).reset();
              context.go('/home');
            })
          : _PayInProgress(tapState: tapState),
    );
  }

  void _startNfc(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(payScreenProvider.notifier);
    notifier.detecting();
    
    // Simulate finding receiver and transferring
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        notifier.transferring();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            notifier.done();
            // In a real scenario, the amount would be received from the receiver over NFC
            // For demo, we just increment pending count
            ref.read(pendingCountProvider.notifier).state++;
          }
        });
      }
    });
  }
}

class _PayInProgress extends StatelessWidget {
  const _PayInProgress({required this.tapState});
  final NfcTapState tapState;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.1),
            duration: const Duration(milliseconds: 700),
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tngBlue.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.contactless, color: AppTheme.tngBlue, size: 56),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            tapState == NfcTapState.detecting ? 'Tap receiver\'s phone' : 'Sending payment...',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          const Text(
            'Keep devices close until finished',
            style: TextStyle(color: AppTheme.offlineGrey, fontSize: 15),
          ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _PayDone extends StatelessWidget {
  const _PayDone({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.settled, size: 80),
            const SizedBox(height: 24),
            const Text('Payment Sent',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text(
              'Your token has been transferred.\nIt will be settled automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.offlineGrey, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(backgroundColor: AppTheme.tngBlue),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
