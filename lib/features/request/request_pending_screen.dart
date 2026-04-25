import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../offline/offline_payment_controller.dart';

class RequestPendingScreen extends ConsumerStatefulWidget {
  const RequestPendingScreen({super.key});

  @override
  ConsumerState<RequestPendingScreen> createState() =>
      _RequestPendingScreenState();
}

class _RequestPendingScreenState extends ConsumerState<RequestPendingScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlinePaymentControllerProvider);
    final notifier = ref.read(offlinePaymentControllerProvider.notifier);
    final pending = state.outgoingRequest;

    ref.listen(
      offlinePaymentControllerProvider
          .select((value) => value.latestIncomingReceipt),
      (previous, next) {
        if (next != null && context.mounted) {
          context.go(RoutePaths.receive);
        }
      },
    );

    if (pending == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Waiting for payment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No active merchant request.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.request),
                  child: const Text('New request'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final request = pending.request;
    final remaining = request.remaining(_now);
    final expired = remaining == Duration.zero;

    return Scaffold(
      appBar: AppBar(title: const Text('Waiting for payment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.amountLabel,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(request.memo.isEmpty ? 'No memo' : request.memo),
                  const SizedBox(height: 16),
                  Text(
                    expired
                        ? 'Request expired'
                        : 'Waiting for payer to tap back...',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expired
                        ? 'The 5-minute request window has ended.'
                        : 'Time remaining: ${_formatDuration(remaining)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (expired) {
                      context.go(RoutePaths.request);
                      return;
                    }
                    await notifier.sendPaymentRequest(
                      amountCents: request.amountCents,
                      memo: request.memo,
                    );
                  },
                  child: Text(expired ? 'New request' : 'Resend request'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    notifier.clearOutgoingRequest();
                    context.go(RoutePaths.home);
                  },
                  child: Text(expired ? 'Done' : 'Cancel'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
