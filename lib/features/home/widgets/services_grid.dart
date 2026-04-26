import 'package:flutter/material.dart';

class ServicesGrid extends StatelessWidget {
  const ServicesGrid({super.key});

  static const _services = [
    _Svc(Icons.directions_car, 'Toll & Parking', Color(0xFF2563EB),
        Color(0xFFEFF6FF)),
    _Svc(Icons.bolt, 'Electricity', Color(0xFFD97706), Color(0xFFFFFBEB)),
    _Svc(Icons.smartphone, 'Prepaid', Color(0xFF059669), Color(0xFFECFDF5)),
    _Svc(Icons.flight, 'Flights', Color(0xFF0284C7), Color(0xFFE0F2FE)),
    _Svc(Icons.movie, 'Movies', Color(0xFFE11D48), Color(0xFFFFF1F2)),
    _Svc(Icons.restaurant, 'Food', Color(0xFFEA580C), Color(0xFFFFF7ED)),
    _Svc(Icons.card_giftcard, 'Vouchers', Color(0xFFDB2777), Color(0xFFFDF2F8)),
    _Svc(Icons.favorite, 'Insurance', Color(0xFFDC2626), Color(0xFFFFF1F2)),
    _Svc(Icons.shopping_bag, 'Shopping', Color(0xFF7C3AED), Color(0xFFF5F3FF)),
    _Svc(Icons.school, 'Education', Color(0xFF4338CA), Color(0xFFEEF2FF)),
    _Svc(Icons.business, 'Bills', Color(0xFF0D9488), Color(0xFFF0FDFA)),
    _Svc(Icons.more_horiz, 'More', Color(0xFF475569), Color(0xFFF1F5F9)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'All Services',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              Text('See all',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 4,
            childAspectRatio: 0.78,
            children: _services.map((s) => _SvcTile(svc: s)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Svc {
  const _Svc(this.icon, this.label, this.fg, this.bg);
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
}

class _SvcTile extends StatelessWidget {
  const _SvcTile({required this.svc});
  final _Svc svc;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: svc.bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(svc.icon, color: svc.fg, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          svc.label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
