// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/pay/pay_screen.dart';
import 'features/receive/receive_screen.dart';
import 'features/pending/pending_screen.dart';
import 'features/history/history_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/score/score_screen.dart';

final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    GoRoute(path: '/onboard', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/pay',     builder: (_, __) => const PayScreen()),
    GoRoute(path: '/receive', builder: (_, __) => const ReceiveScreen()),
    GoRoute(path: '/score',   builder: (_, __) => const ScoreScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/pending', builder: (_, __) => const PendingScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/settings',builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class TngWalletApp extends StatelessWidget {
  const TngWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "AnyPay",
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}

// Shell with bottom navigation
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  static const _routes = ['/home', '/pending', '/history', '/settings'];
  static const _icons = [
    Icons.home_outlined,
    Icons.pending_actions_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];
  static const _labels = ['Home', 'Pending', 'History', 'Me'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _NfcFab(),
      bottomNavigationBar: _BottomBar(
        tab: _tab,
        onTap: (i) {
          setState(() => _tab = i);
          context.go(_routes[i]);
        },
      ),
    );
  }
}

class _NfcFab extends StatelessWidget {
  const _NfcFab();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      height: 66,
      child: FloatingActionButton(
        onPressed: () => context.go('/pay'),
        backgroundColor: AppTheme.tngBlue,
        elevation: 6,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 4)),
        child: const Icon(Icons.nfc, color: Colors.white, size: 30),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tab, required this.onTap});
  final int tab;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          Expanded(child: _NavItem(icon: Icons.home_outlined, label: 'Home', isActive: tab == 0, onTap: () => onTap(0))),
          Expanded(child: _NavItem(icon: Icons.pending_actions_outlined, label: 'Pending', isActive: tab == 1, onTap: () => onTap(1))),
          const SizedBox(width: 56), // spacer for FAB
          Expanded(child: _NavItem(icon: Icons.receipt_long_outlined, label: 'History', isActive: tab == 2, onTap: () => onTap(2))),
          Expanded(child: _NavItem(icon: Icons.person_outline, label: 'Me', isActive: tab == 3, onTap: () => onTap(3))),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.isActive, required this.onTap});
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.tngBlue : AppTheme.offlineGrey;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
