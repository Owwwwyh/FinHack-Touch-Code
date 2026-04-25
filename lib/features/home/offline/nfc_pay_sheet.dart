import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OfflineToken {
  const OfflineToken({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.receiverMac,
    required this.senderMac,
    required this.timestamp,
    required this.signature,
  });
  final String id;
  final double amount;
  final String merchant;
  final String receiverMac;
  final String senderMac;
  final String timestamp;
  final String signature;
}

enum _Stage { entry, detecting, signing }

class NfcPaySheet extends StatefulWidget {
  const NfcPaySheet({super.key, required this.balance});
  final double balance;

  @override
  State<NfcPaySheet> createState() => _NfcPaySheetState();
}

class _NfcPaySheetState extends State<NfcPaySheet> {
  static const _merchants = [
    ('MyNews · KLCC', 'MN:4F:21:A0'),
    ('Starbucks Mid Valley', 'SB:9C:88:11'),
    ('Mr DIY Sunway', 'MD:73:2E:55'),
    ('Family Mart Bangsar', 'FM:1A:0D:64'),
  ];
  static const _presets = [5.0, 10.0, 20.0, 50.0];

  String _amountText = '';
  int _merchantIdx = 0;
  _Stage _stage = _Stage.entry;

  double get _amount => double.tryParse(_amountText) ?? 0;
  bool get _canPay => _amount > 0 && _amount <= widget.balance;

  void _pressKey(String k) {
    if (_stage != _Stage.entry) return;
    setState(() {
      if (k == 'del') {
        _amountText = _amountText.isEmpty
            ? ''
            : _amountText.substring(0, _amountText.length - 1);
      } else if (k == '.' && _amountText.contains('.')) {
        // ignore duplicate decimal
      } else if (_amountText.contains('.') &&
          _amountText.split('.')[1].length >= 2) {
        // max 2 decimal places
      } else if (_amountText == '0' && k != '.') {
        _amountText = k;
      } else {
        _amountText = _amountText + k;
      }
    });
  }

  void _startTap() {
    if (!_canPay) return;
    setState(() => _stage = _Stage.detecting);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _stage = _Stage.signing);
    });
    Future.delayed(const Duration(milliseconds: 2700), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final rng = Random();
      final now = DateTime.now();
      final pad = (int v, int w) => v.toString().padLeft(w, '0');
      final token = OfflineToken(
        id: now.millisecondsSinceEpoch.toRadixString(16),
        amount: _amount,
        merchant: _merchants[_merchantIdx].$1,
        receiverMac: _merchants[_merchantIdx].$2,
        senderMac: 'A4:F2:9B:17',
        timestamp:
            '${now.year}-${pad(now.month, 2)}-${pad(now.day, 2)} ${pad(now.hour, 2)}:${pad(now.minute, 2)}',
        signature:
            List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join(),
      );
      Navigator.pop(context, token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          if (_stage == _Stage.entry) ..._entryContent(),
          if (_stage == _Stage.detecting) ..._detectingContent(),
          if (_stage == _Stage.signing) ..._signingContent(),
        ],
      ),
    );
  }

  List<Widget> _entryContent() => [
        Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offline NFC Payment',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                Text('Enter Amount',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
              ],
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Amount display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text('YOU\'RE SENDING',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF2563EB),
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('RM',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _amountText.isEmpty ? '0' : _amountText,
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1),
                  ),
                ],
              ),
              Text(
                _amount > widget.balance
                    ? 'Exceeds offline cap (RM ${widget.balance.toStringAsFixed(2)})'
                    : 'Available offline: RM ${widget.balance.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11,
                    color: _amount > widget.balance
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('To merchant',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _merchants.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final sel = i == _merchantIdx;
              return GestureDetector(
                onTap: () => setState(() => _merchantIdx = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF2563EB) : Colors.white,
                    border: Border.all(
                        color: sel
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront,
                          size: 12,
                          color: sel ? Colors.white : const Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text(_merchants[i].$1,
                          style: TextStyle(
                              fontSize: 11,
                              color: sel
                                  ? Colors.white
                                  : const Color(0xFF475569))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _presets.map((p) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _amountText = p.toStringAsFixed(0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text('RM ${p.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF475569))),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final k in [
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
              '.',
              '0',
              'del'
            ])
              GestureDetector(
                onTap: () => _pressKey(k),
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: k == 'del'
                      ? const Icon(Icons.backspace_outlined,
                          size: 18, color: Color(0xFF475569))
                      : Text(k,
                          style: const TextStyle(
                              fontSize: 18, color: Color(0xFF0F172A))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _canPay ? _startTap : null,
            icon: const Icon(Icons.nfc),
            label: const Text('Tap to Send Token'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ];

  List<Widget> _detectingContent() => [
        const SizedBox(height: 24),
        const _NfcRipple(),
        const SizedBox(height: 20),
        const Text('Hold your phone near the merchant reader…',
            style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        const Text('Sending token via NFC',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 32),
      ];

  List<Widget> _signingContent() => [
        const SizedBox(height: 36),
        const CircularProgressIndicator(color: Color(0xFF2563EB)),
        const SizedBox(height: 16),
        const Text('Signing token (Ed25519)…',
            style: TextStyle(fontSize: 14, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Recording sender · receiver · amount · time',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 36),
      ];
}

class _NfcRipple extends StatefulWidget {
  const _NfcRipple();

  @override
  State<_NfcRipple> createState() => _NfcRippleState();
}

class _NfcRippleState extends State<_NfcRipple> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (_) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1400)),
    );
    for (int i = 0; i < _ctrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 467), () {
        if (mounted) _ctrls[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < _ctrls.length; i++)
            AnimatedBuilder(
              animation: _ctrls[i],
              builder: (_, __) {
                final v = _ctrls[i].value;
                return Opacity(
                  opacity: ((1 - v) * 0.8).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.6 + v,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: Color(0xFF2563EB)),
            child: const Icon(Icons.nfc, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}
