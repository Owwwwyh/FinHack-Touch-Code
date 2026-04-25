import 'package:flutter/material.dart';

class TngTopBar extends StatelessWidget {
  const TngTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text(
              'A',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.white.withOpacity(0.8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Search services & merchants',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
