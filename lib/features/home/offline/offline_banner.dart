import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.pendingCount});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(color: Color(0xFFFEF3C7), shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off, color: Color(0xFFB45309), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're offline",
                  style: TextStyle(fontSize: 13, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
                ),
                Text(
                  pendingCount > 0
                      ? '$pendingCount transaction${pendingCount > 1 ? 's' : ''} waiting to sync'
                      : 'NFC payments still work',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, color: Color(0xFFB45309), size: 16),
        ],
      ),
    );
  }
}
