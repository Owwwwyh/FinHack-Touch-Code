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
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/pay',     builder: (_, __) => const PayScreen()),
        GoRoute(path: '/receive', builder: (_, __) => const ReceiveScreen()),
        GoRoute(path: '/pending', builder: (_, __) => const PendingScreen()),
        GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
        GoRoute(path: '/score',   builder: (_, __) => const ScoreScreen()),
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
      title: "TNG Offline Wallet",
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
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => context.go('/pay'),
          child: Container(
            width: 66, height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.tngBlue,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: const Icon(Icons.nfc, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
      ],
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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (i) {
          if (i == 2) return const SizedBox(width: 56);
          final active = tab == i;
          final color = active ? AppTheme.tngBlue : AppTheme.offlineGrey;
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 64, height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon([Icons.home_outlined, Icons.pending_actions_outlined, Icons.receipt_long_outlined, Icons.person_outline][i],
                    color: color, size: 24),
                  const SizedBox(height: 3),
                  Text(['Home', 'Pending', 'History', 'Me'][i],
                    style: TextStyle(color: color, fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
