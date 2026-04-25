import 'package:flutter/material.dart';

import '../../domain/models/offline_transfer.dart';
import '../../domain/services/offline_pay_policy.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  static const _policy = OfflinePayPolicy();

  final TextEditingController _amountController = TextEditingController();
  final List<OfflineTransfer> _drafts = <OfflineTransfer>[];

  AmountValidationResult _validation =
      const AmountValidationResult.invalid('Enter an amount to continue.');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _validation = _policy.validateAmountText(value);
    });
  }

  void _setAmount(String amount) {
    _amountController.text = amount;
    _amountController.selection = TextSelection.collapsed(offset: amount.length);
    _onAmountChanged(amount);
  }

  void _prepareTap() {
    final validation = _policy.validateAmountText(_amountController.text);
    if (!validation.isValid || validation.amountCents == null) {
      setState(() {
        _validation = validation;
      });
      return;
    }

    final draft = _policy.createDraft(
      amountCents: validation.amountCents!,
      createdAt: DateTime.now(),
    );

    setState(() {
      _drafts.insert(0, draft);
      _validation = validation;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Prepared ${draft.amountLabel} for NFC tap.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountEnabled = _validation.isValid;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay Offline')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hold near the receiver to prepare an offline token.',
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
                    key: const ValueKey('pay-amount-field'),
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onAmountChanged,
                    decoration: InputDecoration(
                      hintText: '8.50',
                      helperText:
                          'Safe offline balance: RM ${(_policy.safeOfflineBalanceCents / 100).toStringAsFixed(2)}',
                      errorText: _validation.isValid ? null : _validation.message,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AmountChip(label: 'RM 5.00', onTap: () => _setAmount('5.00')),
                      _AmountChip(label: 'RM 8.50', onTap: () => _setAmount('8.50')),
                      _AmountChip(label: 'RM 12.00', onTap: () => _setAmount('12.00')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: amountEnabled ? _prepareTap : null,
                      icon: const Icon(Icons.nfc),
                      label: const Text('Hold near receiver'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_drafts.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prepared NFC tokens',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final draft in _drafts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TransferTile(transfer: draft),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Tap sequence',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('1. Amount validated against safe offline balance.'),
                  Text('2. Keystore signing will be wired in the next slice.'),
                  Text('3. NFC APDU transfer and settlement follow after that.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.transfer});

  final OfflineTransfer transfer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transfer.amountLabel} to ${transfer.receiverKid}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text('tx ${transfer.shortTxId} · ${transfer.status.name}'),
          ],
        ),
      ),
    );
  }
}
