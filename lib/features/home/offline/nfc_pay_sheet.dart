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

enum _Stage {
  entry,
  tap1,
  senderConfirm,
  faceId,
  verified,
  tapMerchant,
  transferring,
}

class NfcPaySheet extends StatefulWidget {
  const NfcPaySheet({super.key, required this.balance});
  final double balance;

  @override
  State<NfcPaySheet> createState() => _NfcPaySheetState();
}

class _NfcPaySheetState extends State<NfcPaySheet> {
  static const _presets = [5.0, 10.0, 20.0, 50.0];

  String _amountText = '';
  _Stage _stage = _Stage.entry;

  double get _amount => double.tryParse(_amountText) ?? 0;
  bool get _canPay => _amount > 0 && _amount <= widget.balance;

  void _pressKey(String k) {
    if (_stage != _Stage.entry) return;
    setState(() {
      if (k == 'del') {
        _amountText = _amountText.isEmpty ? '' : _amountText.substring(0, _amountText.length - 1);
      } else if (k == '.' && _amountText.contains('.')) {
        // ignore duplicate decimal
      } else if (_amountText.contains('.') && _amountText.split('.')[1].length >= 2) {
        // max 2 decimal places
      } else if (_amountText == '0' && k != '.') {
        _amountText = k;
      } else {
        _amountText = _amountText + k;
      }
    });
  }

  // A presses Request → show tap-1 NFC animation
  void _sendRequest() {
    if (!_canPay) return;
    setState(() => _stage = _Stage.tap1);
  }

  // After simulating tap 1 → show B's confirmation
  void _completeTap1() {
    setState(() => _stage = _Stage.senderConfirm);
  }

  // Payer confirms → face ID
  void _confirmSender() {
    setState(() => _stage = _Stage.faceId);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _stage = _Stage.verified);
    });
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _stage = _Stage.tapMerchant);
    });
  }

  // Tap 2: payer taps back → generates token
  void _tapMerchant() {
    setState(() => _stage = _Stage.transferring);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final rng = Random();
      final now = DateTime.now();
      final pad = (int v, int w) => v.toString().padLeft(w, '0');
      final token = OfflineToken(
        id: now.millisecondsSinceEpoch.toRadixString(16),
        amount: _amount,
        merchant: 'Aida Rahman',
        receiverMac: 'NF:C0:AI:DA',
        senderMac: 'A4:F2:9B:17',
        timestamp:
            '${now.year}-${pad(now.month, 2)}-${pad(now.day, 2)} ${pad(now.hour, 2)}:${pad(now.minute, 2)}',
        signature: List.generate(32, (_) => rng.nextInt(16).toRadixString(16)).join(),
      );
      Navigator.pop(context, token);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(_stage),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: _buildStage(),
      ),
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.entry:
        return _EntryStage(
          amountText: _amountText,
          amount: _amount,
          balance: widget.balance,
          presets: _presets,
          canPay: _canPay,
          onKey: _pressKey,
          onClose: () => Navigator.pop(context),
          onSend: _sendRequest,
        );
      case _Stage.tap1:
        return _Tap1Stage(amount: _amount, onTap: _completeTap1);
      case _Stage.senderConfirm:
        return _SenderConfirmStage(
          amount: _amount,
          balance: widget.balance,
          requesterName: 'Aida Rahman',
          onClose: () => Navigator.pop(context),
          onConfirm: _confirmSender,
        );
      case _Stage.faceId:
        return const _FaceIdStage();
      case _Stage.verified:
        return const _VerifiedStage();
      case _Stage.tapMerchant:
        return _TapMerchantStage(amount: _amount, onTap: _tapMerchant);
      case _Stage.transferring:
        return const _TransferringStage();
    }
  }
}

// ─── Stage: Entry (Merchant enters amount) ──────────────────────────────────

class _EntryStage extends StatelessWidget {
  const _EntryStage({
    required this.amountText,
    required this.amount,
    required this.balance,
    required this.presets,
    required this.canPay,
    required this.onKey,
    required this.onClose,
    required this.onSend,
  });

  final String amountText;
  final double amount;
  final double balance;
  final List<double> presets;
  final bool canPay;
  final void Function(String) onKey;
  final VoidCallback onClose;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offline NFC · Tap 1',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('Enter Amount to Request',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
              ],
            ),
            const Spacer(),
            _CloseButton(onTap: onClose),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('REQUESTING',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFF2563EB), letterSpacing: 1.2)),
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
                    amountText.isEmpty ? '0' : amountText,
                    style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -1),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                amount > balance
                    ? 'Exceeds offline cap (RM ${balance.toStringAsFixed(2)})'
                    : 'Payer\'s safe offline balance: RM ${balance.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 11,
                    color: amount > balance
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Quick presets
        Row(
          children: presets.map((p) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onKey(p.toStringAsFixed(0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: Text('RM ${p.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Numpad
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final k in ['1','2','3','4','5','6','7','8','9','.','0','del'])
              GestureDetector(
                onTap: () => onKey(k),
                child: Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: k == 'del'
                      ? const Icon(Icons.backspace_outlined, size: 18, color: Color(0xFF475569))
                      : Text(k, style: const TextStyle(fontSize: 18, color: Color(0xFF0F172A))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canPay ? onSend : null,
            icon: const Icon(Icons.nfc, size: 22),
            label: const Text('Request via NFC',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFCBD5E1),
              disabledForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stage: Sender Confirm (Payer sees request) ──────────────────────────────

class _SenderConfirmStage extends StatelessWidget {
  const _SenderConfirmStage({
    required this.amount,
    required this.balance,
    required this.requesterName,
    required this.onClose,
    required this.onConfirm,
  });

  final double amount;
  final double balance;
  final String requesterName;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final afterPayment = (balance - amount).clamp(0.0, double.infinity);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 8),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Offline NFC · Tap 1 received',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('Confirm Payment',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
              ],
            ),
            const Spacer(),
            _CloseButton(onTap: onClose),
          ],
        ),
        const SizedBox(height: 16),
        // Blue request card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0066FF), Color(0xFF0057E0)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.nfc, color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text('Incoming NFC request from $requesterName',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white24),
              const SizedBox(height: 12),
              const Text('Amount to send',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
              const SizedBox(height: 4),
              Text('RM ${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -1)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Details card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _DetailLine('Paying to', requesterName),
              _DetailLine('Available offline', 'RM ${balance.toStringAsFixed(2)}'),
              _DetailLine('After payment',
                  'RM ${afterPayment.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF059669)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 14, color: Color(0xFF059669)),
            const SizedBox(width: 6),
            const Text('Secured · Ed25519 signed offline token',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0066FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value, {this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

// ─── Stage: Face ID ──────────────────────────────────────────────────────────

class _FaceIdStage extends StatefulWidget {
  const _FaceIdStage();

  @override
  State<_FaceIdStage> createState() => _FaceIdStageState();
}

class _FaceIdStageState extends State<_FaceIdStage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scan;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scan = Tween<double>(begin: 0.1, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(begin: 0.9, end: 1.08).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dashed rotating border
                  Transform.rotate(
                    angle: _ctrl.value * 2 * 3.14159,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: const Color(0xFF3B82F6), width: 3),
                      ),
                    ),
                  ),
                  // Pulsing icon
                  Transform.scale(
                    scale: _pulse.value,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.face_retouching_natural,
                          size: 56, color: Color(0xFF2563EB)),
                    ),
                  ),
                  // Scan line
                  Positioned(
                    top: 140 * _scan.value,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('Scanning Face ID…',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Verifying identity to authorize payment',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── Stage: Verified ─────────────────────────────────────────────────────────

class _VerifiedStage extends StatefulWidget {
  const _VerifiedStage();

  @override
  State<_VerifiedStage> createState() => _VerifiedStageState();
}

class _VerifiedStageState extends State<_VerifiedStage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 32),
        AnimatedBuilder(
          animation: _scale,
          builder: (_, __) => Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                  color: Color(0xFF059669), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 56),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Identity Verified',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Payment authorized',
            style: TextStyle(fontSize: 14, color: Color(0xFF059669))),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── Stage: Tap 1 (A holds phone near B) ─────────────────────────────────────

class _Tap1Stage extends StatelessWidget {
  const _Tap1Stage({required this.amount, required this.onTap});
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 12),
        const Text('Offline NFC · Tap 1',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text('Requesting  RM ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 28),
        _NfcRipple(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16)),
          child: const Text('Hold your phone near the payer\'s device',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.nfc, size: 22),
            label: const Text('Hold & Tap NFC',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stage: Tap Merchant (Payer taps back — Tap 2) ───────────────────────────

class _TapMerchantStage extends StatelessWidget {
  const _TapMerchantStage({required this.amount, required this.onTap});
  final double amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 12),
        const Text('Offline NFC · Tap 2',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        const Text('Tap back to send signed token',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 28),
        _NfcRipple(),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Text('Hold your phone near the merchant\'s device',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Transferring signed token → ',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  Text('RM ${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.nfc, size: 22),
            label: const Text('Tap NFC to Pay',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0066FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Stage: Transferring ─────────────────────────────────────────────────────

class _TransferringStage extends StatelessWidget {
  const _TransferringStage();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DragHandle(),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Color(0xFF2563EB)),
        const SizedBox(height: 18),
        const Text('Transferring token…',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        const Text('Signing & handing off via NFC',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
            color: Color(0xFFF1F5F9), shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 18, color: Color(0xFF475569)),
      ),
    );
  }
}

class _NfcRipple extends StatefulWidget {
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
          vsync: this, duration: const Duration(milliseconds: 1600)),
    );
    for (int i = 0; i < _ctrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
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
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (int i = 0; i < _ctrls.length; i++)
            AnimatedBuilder(
              animation: _ctrls[i],
              builder: (_, __) {
                final v = _ctrls[i].value;
                return Opacity(
                  opacity: ((1 - v) * 0.75).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + v * 1.2,
                    child: Container(
                      width: 144,
                      height: 144,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF3B82F6), width: 2),
                      ),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0066FF), Color(0xFF0057E0)],
              ),
            ),
            child: const Icon(Icons.nfc, color: Colors.white, size: 44),
          ),
        ],
      ),
    );
  }
}
