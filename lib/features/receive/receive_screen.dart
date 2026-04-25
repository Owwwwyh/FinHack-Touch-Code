import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/offline_transfer.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  static const _inboxChannel = EventChannel('com.tng.finhack/inbox');

  StreamSubscription<dynamic>? _sub;
  final List<OfflineTransfer> _inbox = [];
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _sub = _inboxChannel.receiveBroadcastStream().listen(
      _onTokenReceived,
      onError: (dynamic err) {
        // HCE service not active yet or NFC unavailable — silently ignore
      },
    );
    setState(() => _listening = true);
  }

  void _onTokenReceived(dynamic event) {
    if (event is! Map) return;
    final jws = event['jws'] as String? ?? '';
    final ackSig = event['ackSig'] as String?;

    // Parse the JWS payload to extract amount and tx_id
    final parts = jws.split('.');
    if (parts.length != 3) return;

    Map<String, dynamic> payload;
    try {
      final padded = base64Url.normalize(parts[1]);
      payload = jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final txId = payload['tx_id'] as String? ?? '';
    final amountMap = payload['amount'] as Map? ?? {};
    final amountValue = amountMap['value'] as String? ?? '0';
    final amountCents = (double.tryParse(amountValue) ?? 0.0) * 100;

    final senderMap = payload['sender'] as Map? ?? {};
    final senderKid = senderMap['kid'] as String? ?? 'unknown';

    final transfer = OfflineTransfer(
      txId: txId,
      amountCents: amountCents.round(),
      receiverKid: senderKid,
      createdAt: DateTime.now(),
      status: OfflineTransferStatus.pendingSettlement,
      ackSignature: ackSig,
    );

    if (mounted) {
      setState(() => _inbox.insert(0, transfer));
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Offline')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hold the sender\'s phone near this device to receive a payment.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.nfc,
                    color: _listening ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _listening ? 'HCE active — ready to receive' : 'Starting HCE…',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _listening
                              ? 'This device is registered as an NFC receiver'
                              : 'Waiting for HCE service',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_listening)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_inbox.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Pending receipts',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 12),
                    Center(
                      child: Text(
                        'No tokens received yet',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending receipts (${_inbox.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final t in _inbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReceiveTile(transfer: t),
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

class _ReceiveTile extends StatelessWidget {
  const _ReceiveTile({required this.transfer});

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
            const Icon(Icons.call_received, size: 16, color: Color(0xFF22C55E)),
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
                    'tx …${transfer.shortTxId} · ${_statusLabel(transfer.status)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            _StatusChip(status: transfer.status),
          ],
        ),
      ),
    );
  }

  String _statusLabel(OfflineTransferStatus s) => switch (s) {
        OfflineTransferStatus.pendingNfc => 'pending NFC',
        OfflineTransferStatus.pendingSettlement => 'pending settlement',
        OfflineTransferStatus.settled => 'settled',
        OfflineTransferStatus.rejected => 'rejected',
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final OfflineTransferStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OfflineTransferStatus.pendingNfc => ('NFC', Colors.orange),
      OfflineTransferStatus.pendingSettlement => ('Pending', Colors.blue),
      OfflineTransferStatus.settled => ('Settled', Colors.green),
      OfflineTransferStatus.rejected => ('Rejected', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
