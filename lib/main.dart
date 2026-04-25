import "package:flutter/material.dart";

void main() {
  runApp(const TngCloneApp());
}

class TngCloneApp extends StatelessWidget {
  const TngCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TNG Clone",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF015CE6)),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final clampedText = media.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.0,
        );
        return MediaQuery(
          data: media.copyWith(textScaler: clampedText),
          child: _PhoneViewport(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const AppShell(),
    );
  }
}

class _PhoneViewport extends StatelessWidget {
  const _PhoneViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth <= 460) {
          return child;
        }

        return Container(
          color: const Color(0xFF0F172A),
          child: Center(
            child: Container(
              width: 420,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      HomeScreen(
        onOpenPay: () => _openPage(context, const PayScreen()),
        onOpenTransfer: () => _openPage(context, const TransferScreen()),
        onOpenReload: () => _openPage(context, const ReloadScreen()),
      ),
      const HistoryScreen(),
      const SizedBox.shrink(),
      const ServiceScreen(title: "GOrewards"),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentTab, children: tabs),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: GestureDetector(
        onTap: () => _openPage(context, const PayScreen()),
        child: Container(
          height: 70,
          width: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0B57C7),
            border: Border.all(color: Colors.white, width: 5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 30),
        ),
      ),
      bottomNavigationBar: Container(
        height: 82,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomItem(
              icon: Icons.home_outlined,
              label: "Home",
              active: _currentTab == 0,
              onTap: () => setState(() => _currentTab = 0),
            ),
            _BottomItem(
              icon: Icons.receipt_long_outlined,
              label: "Transactions",
              active: _currentTab == 1,
              onTap: () => setState(() => _currentTab = 1),
            ),
            const SizedBox(width: 54),
            _BottomItem(
              icon: Icons.card_giftcard_outlined,
              label: "GOrewards",
              active: _currentTab == 3,
              onTap: () => setState(() => _currentTab = 3),
            ),
            _BottomItem(
              icon: Icons.person_outline,
              label: "Me",
              active: _currentTab == 4,
              onTap: () => setState(() => _currentTab = 4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenPay,
    required this.onOpenTransfer,
    required this.onOpenReload,
  });

  final VoidCallback onOpenPay;
  final VoidCallback onOpenTransfer;
  final VoidCallback onOpenReload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                height: 228,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
                color: const Color(0xFF004A9D),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: Colors.white,
                          child: Text(
                            "JM",
                            style: TextStyle(
                              color: Color(0xFF004A9D),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "eWallet Balance",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 34 / 2,
                          ),
                        ),
                        Spacer(),
                        Icon(Icons.help_outline, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Icon(Icons.notifications_none, color: Colors.white, size: 28),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "RM 245.80",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 46,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        _TopPill(text: "GO+ RM 1,200.50"),
                        SizedBox(width: 10),
                        _TopPill(text: "GOrewards 450 pts"),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 22,
                right: 22,
                bottom: -62,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FD),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ActionButton(icon: Icons.qr_code_scanner, label: "Scan", onTap: onOpenPay),
                      _ActionButton(icon: Icons.qr_code_2_outlined, label: "Pay", onTap: onOpenPay),
                      _ActionButton(icon: Icons.swap_horiz, label: "Transfer", onTap: onOpenTransfer, activeColor: const Color(0xFFD91C5C)),
                      _ActionButton(icon: Icons.add_circle_outline, label: "Reload", onTap: onOpenReload),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 74),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 18,
              children: [
                _ServiceChip(label: "Toll", icon: Icons.directions_car_outlined),
                _ServiceChip(label: "Parking", icon: Icons.location_on_outlined),
                _ServiceChip(label: "Prepaid", icon: Icons.smartphone_outlined),
                _ServiceChip(label: "Bills", icon: Icons.description_outlined),
                _ServiceChip(label: "Postpaid", icon: Icons.phone_outlined),
                _ServiceChip(label: "Movies", icon: Icons.confirmation_num_outlined),
                _ServiceChip(label: "Flights", icon: Icons.flight_outlined),
                _ServiceChip(label: "Insurance", icon: Icons.umbrella_outlined),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 8, color: const Color(0xFFEDEDED)),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Text(
              "Discover GOfinance",
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 18),
              children: [
                _PromoCard(
                  title: "Grow Your Money",
                  subtitle: "Earn daily returns with GO+",
                  button: "Invest Now",
                  color: Color(0xFF08173E),
                ),
                SizedBox(width: 14),
                _PromoCard(
                  title: "GOprotect",
                  subtitle: "Affordable insurance plans",
                  button: "Learn More",
                  color: Color(0xFF8A1AA0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.activeColor = const Color(0xFF015CE6),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF015CE6), size: 24),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF1F2937),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, color: Colors.white, size: 16),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.title,
    required this.subtitle,
    required this.button,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String button;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Text(
              button,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF015CE6) : const Color(0xFF6B7280);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = [
      ("Toll Plaza Batu Tiga", "-RM 2.10"),
      ("KK Super Mart", "-RM 15.40"),
      ("Transfer from Jane", "+RM 50.00"),
      ("Reload via FPX", "+RM 100.00"),
    ];

    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const Divider(),
        itemBuilder: (_, index) {
          final item = transactions[index];
          final isIn = item.$2.startsWith("+");
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isIn
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFEEF5FF),
                  child: Icon(
                    isIn ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isIn
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF015CE6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Recent transaction",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isIn ? const Color(0xFF16A34A) : Colors.black87,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF015CE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF015CE6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("Pay"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text("Show QR code to merchant"),
                      const SizedBox(height: 16),
                      Container(height: 80, color: Colors.black),
                      const SizedBox(height: 12),
                      const Text("7845 2011 3940 1284"),
                      const SizedBox(height: 16),
                      Container(
                        height: 180,
                        width: 180,
                        color: Colors.grey.shade300,
                        alignment: Alignment.center,
                        child: const Icon(Icons.qr_code_2, size: 80),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SimpleListPage(
      title: "Transfer",
      items: [
        "DuitNow Transfer",
        "Bank Account",
        "eWallet",
      ],
    );
  }
}

class ReloadScreen extends StatefulWidget {
  const ReloadScreen({super.key});

  @override
  State<ReloadScreen> createState() => _ReloadScreenState();
}

class _ReloadScreenState extends State<ReloadScreen> {
  int amount = 50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reload eWallet")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Reload Amount"),
                    const SizedBox(height: 6),
                    Text(
                      "RM $amount",
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [20, 50, 100, 200].map((value) {
                        return ChoiceChip(
                          label: Text("RM $value"),
                          selected: amount == value,
                          onSelected: (_) => setState(() => amount = value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SimpleCardItem(title: "Bank Card", subtitle: "Visa / Mastercard"),
            const _SimpleCardItem(title: "Online Banking", subtitle: "FPX Transfer"),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: Text("Reload RM $amount"),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Text("JM")),
            title: Text("John M."),
            subtitle: Text("+60 12-345 6789"),
          ),
        ),
        SizedBox(height: 12),
        _SimpleCardItem(title: "Settings", subtitle: "App preferences"),
        _SimpleCardItem(title: "Help Center", subtitle: "Support and FAQ"),
        _SimpleCardItem(title: "Log Out", subtitle: "Sign out from account"),
      ],
    );
  }
}

class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _SimpleListPage(
      title: title,
      items: const ["Feature placeholder", "Coming soon"],
    );
  }
}

class _SimpleListPage extends StatelessWidget {
  const _SimpleListPage({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) => ListTile(title: Text(items[index])),
      ),
    );
  }
}

class _SimpleCardItem extends StatelessWidget {
  const _SimpleCardItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
