import 'package:flutter/material.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  bool _waiting = true;
  String? _lastReceived;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receive')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.nfc, size: 80, color: Color(0xFF0061A8)),
              const SizedBox(height: 20),
              const Text(
                'Hold sender\'s phone\nnear this one',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              if (_waiting)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Waiting for tap...', style: TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
              if (_lastReceived != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF16A34A)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 40),
                      const SizedBox(height: 8),
                      Text('Received $_lastReceived', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
                      const SizedBox(height: 4),
                      Text('pending settlement', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              // Last received history
              const Divider(),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Last received:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
              ),
              const SizedBox(height: 8),
              _HistoryRow(amount: 'RM 12.00', status: 'Pending'),
              _HistoryRow(amount: 'RM 5.00', status: 'Settled'),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String amount;
  final String status;

  const _HistoryRow({required this.amount, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('Last received: $amount', style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text('($status)', style: TextStyle(fontSize: 12, color: status == 'Settled' ? const Color(0xFF16A34A) : const Color(0xFFFFA000))),
        ],
      ),
    );
  }
}
