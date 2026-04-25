// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/di/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simMode = ref.watch(nfcSimModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Demo Options', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.offlineGrey)),
          ),
          SwitchListTile(
            title: const Text('NFC Simulator Mode'),
            subtitle: const Text('Delay simulation instead of using real NFC hardware'),
            value: simMode,
            onChanged: (v) => ref.read(nfcSimModeProvider.notifier).state = v,
          ),
          ListTile(
            title: const Text('Reset Wallet State'),
            subtitle: const Text('Clear pending tokens and reset balance'),
            leading: const Icon(Icons.refresh),
            onTap: () {
              ref.read(pendingCountProvider.notifier).state = 0;
              ref.read(walletProvider.notifier).updateFromServer(
                balanceMyr: 248.50,
                safeOfflineMyr: 120.00,
                policyVersion: 'v1.demo',
              );
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet reset to demo state')));
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('Device Security', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.offlineGrey)),
          ),
          const ListTile(
            title: Text('Key ID'),
            subtitle: Text('did:tng:device:LOCAL_TEST_DEVICE'),
            leading: Icon(Icons.key),
          ),
        ],
      ),
    );
  }
}
