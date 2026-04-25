import 'package:flutter/material.dart';

class TngStatusBar extends StatelessWidget {
  const TngStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: const [
          Text(
            '9:41',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          Spacer(),
          Icon(Icons.signal_cellular_alt, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Icon(Icons.wifi, color: Colors.white, size: 16),
          SizedBox(width: 4),
          Icon(Icons.battery_full, color: Colors.white, size: 18),
        ],
      ),
    );
  }
}
