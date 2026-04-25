import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'nfc_pay_sheet.dart';

class TokenReceiptScreen extends StatelessWidget {
  const TokenReceiptScreen({super.key, required this.token, required this.onDone});
  final OfflineToken token;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final json = '{\n'
        '  "tx": "${token.id}",\n'
        '  "amt": ${token.amount},\n'
        '  "to": "${token.receiverMac}",\n'
        '  "from": "${token.senderMac}",\n'
        '  "t": "${token.timestamp}",\n'
        '  "sig": "${token.signature}"\n'
        '}';

    return Material(
      color: const Color(0xFFF1F5F9),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0066FF), Color(0xFF0057E0)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  const Text('Offline Payment Authorized',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    'RM ${token.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Will sync when ${token.merchant} or you reconnect',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _card(
                      child: Column(
                        children: [
                          _DetailRow(
                            iconBg: const Color(0xFFFEE2E2),
                            iconColor: const Color(0xFFDC2626),
                            icon: Icons.arrow_upward,
                            topLabel: 'From (you)',
                            mainText: 'Aisha Rahman',
                            sideText: token.senderMac,
                          ),
                          const _Divider(),
                          _DetailRow(
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            icon: Icons.arrow_downward,
                            topLabel: 'To',
                            mainText: token.merchant,
                            sideText: token.receiverMac,
                          ),
                          const _Divider(),
                          _DetailRow(
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: const Color(0xFF2563EB),
                            icon: Icons.access_time,
                            topLabel: 'Timestamp',
                            mainText: token.timestamp,
                            sideText: '',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_outline, color: Color(0xFF2563EB), size: 18),
                              const SizedBox(width: 6),
                              const Text('Encrypted Token',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A))),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(20)),
                                child: const Text('Signed · Ed25519',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF059669))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              json,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  color: Color(0xFF6EE7B7),
                                  height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'This token has been transferred to the merchant via NFC as proof of payment. '
                            'Once either device is online, TNG settles the balance.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.5),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Clipboard.setData(ClipboardData(text: json)),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Copy'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.share, size: 16),
                                  label: const Text('Share'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF475569),
                                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A5F)),
                          children: [
                            const TextSpan(text: 'Status: '),
                            const TextSpan(
                              text: 'Pending Settlement',
                              style: TextStyle(
                                  color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                                text:
                                    ' — Token #${token.id.substring(0, 8)} stored locally and on the merchant\'s device.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: child,
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 0),
        child: Divider(height: 1, color: Color(0xFFF1F5F9)),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.iconBg,
    required this.iconColor,
    required this.icon,
    required this.topLabel,
    required this.mainText,
    required this.sideText,
  });
  final Color iconBg;
  final Color iconColor;
  final IconData icon;
  final String topLabel;
  final String mainText;
  final String sideText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topLabel, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                Text(mainText, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
              ],
            ),
          ),
          if (sideText.isNotEmpty)
            Text(sideText,
                style: const TextStyle(
                    fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
