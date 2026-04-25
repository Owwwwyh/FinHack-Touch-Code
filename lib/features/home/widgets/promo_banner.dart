import 'package:flutter/material.dart';

class PromoBanner extends StatelessWidget {
  const PromoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: const [
          Expanded(
            child: _BannerCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBBF24), Color(0xFFF97316)],
              ),
              title: 'Reload & get',
              subtitle: 'RM 5 cashback',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _BannerCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEC4899), Color(0xFFE11D48)],
              ),
              title: 'GO+ Daily',
              subtitle: 'Up to 3.5% p.a.',
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.gradient, required this.title, required this.subtitle});
  final LinearGradient gradient;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
