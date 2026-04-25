import 'package:flutter/material.dart';

import '../../domain/models/offline_transfer.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final List<OfflineTransfer> _inbox = <OfflineTransfer>[];

  void _simulateReceiveTap() {
    final now = DateTime.now();
    final transfer = OfflineTransfer(
      txId: '01${now.millisecondsSinceEpoch}850',
      amountCents: 850,
      receiverKid: '01HW4…a3f4',
      createdAt: now,
      status: OfflineTransferStatus.pendingSettlement,
      ackSignature: 'ack:${now.millisecondsSinceEpoch}',
    );

    setState(() {
      _inbox.insert(0, transfer);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive Offline')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Hold the sender phone near this device to receive a token.',
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
                    'NFC receive mode',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Waiting for tap...'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _simulateReceiveTap,
                      icon: const Icon(Icons.nfc),
                      label: const Text('Simulate incoming tap'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_inbox.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending receipts',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (final transfer in _inbox)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReceiveTile(transfer: transfer),
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
                  children: const [
                    Text(
                      'Last received',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text('RM 12.00 (pending settlement)'),
                    Text('RM 5.00 (settled)'),
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
                    'Next slice',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text('HCE chunk reassembly and ack signatures will land next.'),
                  Text('This screen already shows the pending inbox state.'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transfer.amountLabel} pending settlement',
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
