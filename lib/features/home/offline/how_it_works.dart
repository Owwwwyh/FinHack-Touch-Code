import 'package:flutter/material.dart';

class HowItWorks extends StatefulWidget {
  const HowItWorks({super.key, required this.cap});
  final double cap;

  @override
  State<HowItWorks> createState() => _HowItWorksState();
}

class _HowItWorksState extends State<HowItWorks> with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _sizeFactor;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _sizeFactor = _ctrl.drive(CurveTween(curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'How offline NFC payments work',
                      style: TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8), size: 20),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _sizeFactor,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _step('Tap your phone on the NFC reader at checkout'),
                  _step('Up to RM ${widget.cap.toStringAsFixed(0)} stored securely on device'),
                  _step('Receipts queue locally and auto-sync when online'),
                  _step('Each tap is signed with your offline NFC token'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text('• $text',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4)),
      );
}
