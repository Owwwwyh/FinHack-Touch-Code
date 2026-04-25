import 'package:flutter/material.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String _amount = '';
  static const _safeOfflineLimit = 'RM 120.00';
  bool _tapDetected = false;
  bool _authorizing = false;

  void _onDigit(String digit) {
    setState(() {
      if (_amount.length < 8) _amount += digit;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
    });
  }

  String _formatAmount() {
    if (_amount.isEmpty) return '0.00';
    final val = double.tryParse(_amount) ?? 0;
    return val.toStringAsFixed(2);
  }

  double get _amountValue => double.tryParse(_amount) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0061A8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0061A8),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pay'),
      ),
      body: SafeArea(
        child: _tapDetected ? _buildAuthorization() : _buildAmountEntry(),
      ),
    );
  }

  Widget _buildAmountEntry() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'RM  ${_formatAmount()}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 42),
        ),
        const SizedBox(height: 8),
        Text(
          'Safe offline limit: $_safeOfflineLimit',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        ),
        if (_amountValue > 120)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Exceeds safe offline limit', style: TextStyle(color: Colors.red.shade200, fontSize: 13)),
          ),
        const SizedBox(height: 30),
        // NFC ready indicator
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              Icon(Icons.nfc, color: Colors.white, size: 36),
              SizedBox(height: 8),
              Text('Hold near receiver', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Spacer(),
        // Numpad
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Row(children: ['1', '2', '3'].map((d) => _buildNumButton(d)).toList()),
              Row(children: ['4', '5', '6'].map((d) => _buildNumButton(d)).toList()),
              Row(children: ['7', '8', '9'].map((d) => _buildNumButton(d)).toList()),
              Row(children: [
                _buildNumButton('.'),
                _buildNumButton('0'),
                Expanded(child: IconButton(onPressed: _onBackspace, icon: const Icon(Icons.backspace_outlined, color: Color(0xFF6B7280)))),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNumButton(String digit) {
    return Expanded(
      child: TextButton(
        onPressed: () => _onDigit(digit),
        child: Text(digit, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
      ),
    );
  }

  Widget _buildAuthorization() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('●●●  Tap detected', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text('RM ${_formatAmount()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 42)),
            const SizedBox(height: 8),
            const Text('to: device …a3f4', style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _authorizing ? null : () {
                setState(() => _authorizing = true);
                // TODO: Trigger biometric/PIN + NFC send
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                });
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0061A8)),
              child: _authorizing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Authorize with PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
