import 'package:flutter/material.dart';

class PendingTxn {
  const PendingTxn({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.time,
  });
  final String id;
  final String merchant;
  final double amount;
  final String time;
}

class PendingQueue extends StatelessWidget {
  const PendingQueue({super.key, required this.items});
  final List<PendingTxn> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Pending Sync',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off,
                          color: Color(0xFFB45309), size: 11),
                      const SizedBox(width: 3),
                      Text('${items.length} queued',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFFB45309))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Text(
                'No offline transactions yet.\nTap the NFC button below to pay.',
                style: TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8), height: 1.5),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7), shape: BoxShape.circle),
                      child: const Icon(Icons.access_time,
                          color: Color(0xFFB45309), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(items[i].merchant,
                              style: const TextStyle(
                                  fontSize: 14, color: Color(0xFF0F172A))),
                          Text('${items[i].time} · awaiting sync',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ),
                    ),
                    Text('-RM ${items[i].amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
