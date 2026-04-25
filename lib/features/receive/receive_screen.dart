// lib/features/receive/receive_screen.dart
//
// UPDATED: Receiver side — Enter amount and wait for payer to tap.
// This implements the flow where the merchant/receiver sets the price.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});
  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  String _amount = '0';
  bool _isWaitingForTap = false;

  void _onKey(String k) {
    setState(() {
      if (k == '⌫') {
        _amount = _amount.length > 1 ? _amount.substring(0, _amount.length - 1) : '0';
      } else if (k == '.') {
        if (!_amount.contains('.')) _amount += '.';
      } else {
        _amount = _amount == '0' ? k : _amount + k;
        final parts = _amount.split('.');
        if (parts.length == 2 && parts[1].length > 2) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      }
    });
  }

  void _startReceiving() {
    setState(() => _isWaitingForTap = true);
    // Simulate NFC reception
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Received RM $_amount successfully!'),
            backgroundColor: AppTheme.settled,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _isWaitingForTap 
        ? _WaitingForTap(amount: _amount)
        : _AmountEntry(
            amount: _amount,
            onKey: _onKey,
            onReceive: double.parse(_amount) > 0 ? _startReceiving : null,
          ),
    );
  }
}

class _AmountEntry extends StatelessWidget {
  const _AmountEntry({required this.amount, required this.onKey, required this.onReceive});
  final String amount;
  final void Function(String) onKey;
  final VoidCallback? onReceive;

  static const _keys = [
    ['1','2','3'],
    ['4','5','6'],
    ['7','8','9'],
    ['.','0','⌫'],
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text('Enter amount to receive', 
            style: TextStyle(color: AppTheme.offlineGrey, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'RM $amount',
            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: AppTheme.tngBlueDark),
          ),
          const Spacer(),
          for (final row in _keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) => _NumKey(label: k, onTap: () => onKey(k))).toList(),
              ),
            ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: FilledButton(
              onPressed: onReceive,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.tngBlue,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.all(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72, height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
          ),
          child: Text(label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _WaitingForTap extends StatelessWidget {
  const _WaitingForTap({required this.amount});
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Waiting for payer...', style: TextStyle(fontSize: 18, color: AppTheme.offlineGrey)),
          const SizedBox(height: 8),
          Text('RM $amount', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800)),
          const SizedBox(height: 40),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1.1),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tngBlue.withValues(alpha: 0.1),
                border: Border.all(color: AppTheme.tngBlue.withValues(alpha: 0.2), width: 4),
              ),
              child: const Icon(Icons.nfc, size: 70, color: AppTheme.tngBlue),
            ),
          ),
          const SizedBox(height: 40),
          const CircularProgressIndicator(),
          const SizedBox(height: 40),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Hold the payer\'s phone against yours to receive the token',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.offlineGrey),
            ),
          ),
        ],
      ),
    );
  }
}
