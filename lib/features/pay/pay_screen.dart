import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/crypto/native_jws_signer.dart';
import '../../core/crypto/native_keystore.dart';
import '../../core/nfc/nfc_sender.dart';
import '../../domain/models/offline_transfer.dart';
import '../../domain/services/offline_pay_policy.dart';

enum _NfcPayState { idle, waitingForTap, signing, sending, success, error }

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  static const _policy = OfflinePayPolicy();

  final TextEditingController _amountController = TextEditingController();
  final List<OfflineTransfer> _outbox = [];

  AmountValidationResult _validation =
      const AmountValidationResult.invalid('Enter an amount to continue.');
  _NfcPayState _nfcState = _NfcPayState.idle;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() => _validation = _policy.validateAmountText(value));
  }

  void _setAmount(String amount) {
    _amountController.text = amount;
    _amountController.selection = TextSelection.collapsed(offset: amount.length);
    _onAmountChanged(amount);
  }

  Future<void> _startNfcPay() async {
    final amountCents = _validation.amountCents;
    if (!_validation.isValid || amountCents == null) return;

    setState(() => _nfcState = _NfcPayState.waitingForTap);

    try {
      // Ensure we have a signing key
      if (!await NativeKeystore.keyExists('tng_signing_v1')) {
        await NativeKeystore.generateKey('tng_signing_v1', Uint8List(0));
      }
      final senderPub = await NativeKeystore.getPublicKey('tng_signing_v1');

      // Step 1: SELECT — get receiver pub key
      setState(() => _nfcState = _NfcPayState.waitingForTap);
      final receiverPub = await NfcSender.selectAndGetReceiverPub();
      if (receiverPub == null || receiverPub.length != 32) {
        throw const NfcException('NFC_ERROR', 'No receiver detected');
      }

      // Step 2: Sign JWS
      setState(() => _nfcState = _NfcPayState.signing);
      final signer = NativeJwsSigner(
        kid: 'did:tng:device:local',
        policy: _policy.policyVersion,
        senderPub: senderPub,
      );
      final txId = _generateTxId();
      final jws = await signer.signTransaction(
        txId: txId,
        userId: 'u_local',
        receiverKid: 'did:tng:device:receiver',
        receiverPub: receiverPub,
        amountCents: amountCents,
        policySignedBalance: (_policy.safeOfflineBalanceCents / 100.0).toStringAsFixed(2),
      );

      // Step 3: Send JWS chunks + get ack
      setState(() => _nfcState = _NfcPayState.sending);
      final ackSigBytes = await NfcSender.sendJwsAndGetAck(jws);
      final ackSig = base64Url.encode(ackSigBytes).replaceAll('=', '');

      // Step 4: Store in outbox
      final transfer = OfflineTransfer(
        txId: txId,
        amountCents: amountCents,
        receiverKid: 'did:tng:device:receiver',
        createdAt: DateTime.now(),
        status: OfflineTransferStatus.pendingSettlement,
        ackSignature: ackSig,
      );

      setState(() {
        _outbox.insert(0, transfer);
        _nfcState = _NfcPayState.success;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent ${transfer.amountLabel} — tap complete!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on NfcException catch (e) {
      setState(() => _nfcState = _NfcPayState.error);
      _showError('NFC error: ${e.message}');
    } catch (e) {
      setState(() => _nfcState = _NfcPayState.error);
      _showError('Error: $e');
    } finally {
      await NfcSender.stopReaderMode();
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _nfcState = _NfcPayState.idle);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _generateTxId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '01${ms.toRadixString(36).padLeft(12, '0').toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final canPay = _validation.isValid && _nfcState == _NfcPayState.idle;

    return Scaffold(
      appBar: AppBar(title: const Text('Pay Offline')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hold near the receiver to send an offline payment.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('pay-amount-field'),
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onAmountChanged,
                    enabled: _nfcState == _NfcPayState.idle,
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
                  _NfcStatusBar(state: _nfcState),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: canPay ? _startNfcPay : null,
                      icon: const Icon(Icons.nfc),
                      label: Text(_nfcState == _NfcPayState.idle
                          ? 'Hold near receiver'
                          : _nfcStateLabel(_nfcState)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_outbox.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Outbox (pending settlement)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final t in _outbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TransferTile(transfer: t),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nfcStateLabel(_NfcPayState s) => switch (s) {
        _NfcPayState.waitingForTap => 'Waiting for tap…',
        _NfcPayState.signing => 'Signing…',
        _NfcPayState.sending => 'Sending…',
        _NfcPayState.success => 'Done!',
        _NfcPayState.error => 'Error — tap to retry',
        _NfcPayState.idle => 'Hold near receiver',
      };
}

class _NfcStatusBar extends StatelessWidget {
  const _NfcStatusBar({required this.state});

  final _NfcPayState state;

  @override
  Widget build(BuildContext context) {
    if (state == _NfcPayState.idle) return const SizedBox.shrink();

    final (icon, color, label) = switch (state) {
      _NfcPayState.waitingForTap => (Icons.nfc, Colors.blue, 'Waiting for NFC tap…'),
      _NfcPayState.signing => (Icons.lock, Colors.orange, 'Signing with Keystore…'),
      _NfcPayState.sending => (Icons.sync, Colors.blue, 'Sending token…'),
      _NfcPayState.success => (Icons.check_circle, Colors.green, 'Payment sent!'),
      _NfcPayState.error => (Icons.error, Colors.red, 'NFC error'),
      _NfcPayState.idle => (Icons.nfc, Colors.grey, ''),
    };

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
        if (state == _NfcPayState.waitingForTap ||
            state == _NfcPayState.signing ||
            state == _NfcPayState.sending) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
        ],
      ],
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(label: Text(label), onPressed: onTap);
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
        child: Row(
          children: [
            const Icon(Icons.send, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.amountLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'tx …${transfer.shortTxId} · ${transfer.status.name}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Icon(
              transfer.status == OfflineTransferStatus.settled
                  ? Icons.check_circle
                  : Icons.schedule,
              size: 16,
              color: transfer.status == OfflineTransferStatus.settled
                  ? Colors.green
                  : Colors.orange,
            ),
          ],
        ),
      ),
    );
  }
}
