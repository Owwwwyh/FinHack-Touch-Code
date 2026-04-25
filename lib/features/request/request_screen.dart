import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../offline/offline_payment_controller.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({super.key});

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String? _validationMessage;

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final parsed = double.tryParse(_amountController.text.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return (parsed * 100).round();
  }

  Future<void> _sendRequest() async {
    final amountCents = _amountCents;
    if (amountCents == null) {
      setState(() {
        _validationMessage = 'Enter a valid amount before tap 1.';
      });
      return;
    }

    setState(() => _validationMessage = null);
    final success = await ref
        .read(offlinePaymentControllerProvider.notifier)
        .sendPaymentRequest(
          amountCents: amountCents,
          memo: _memoController.text,
        );
    if (success && mounted) {
      context.go(RoutePaths.requestPending);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offlinePaymentControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Request Payment')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Tap 1 starts here. Enter the amount on the merchant phone, then tap the payer phone to deliver the request.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('request-amount-field'),
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: '8.50',
                      errorText: _validationMessage,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Memo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _memoController,
                    decoration: const InputDecoration(
                      hintText: 'Nasi lemak + teh tarik',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.isSendingRequest ? null : _sendRequest,
                      icon: const Icon(Icons.nfc),
                      label: Text(
                        state.isSendingRequest
                            ? 'Sending tap 1...'
                            : 'Tap payer phone',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
