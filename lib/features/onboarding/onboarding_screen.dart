import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/providers.dart';
import '../../core/theme/app_theme.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.nfc, color: AppTheme.tngBlue, size: 80),
              const SizedBox(height: 32),
              const Text('Welcome to\nTNG Offline',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2)),
              const SizedBox(height: 16),
              const Text(
                'Pay anywhere, anytime.\nEven without an internet connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.offlineGrey, fontSize: 16, height: 1.5),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Registering device keys...')));
                  
                  await ref.read(devicesApiProvider).registerDevice(
                    userId: 'u_demo',
                    publicKeyBase64: 'mock_pub_key',
                    attestationChain: [],
                  );
                  
                  if (context.mounted) {
                    context.go('/home');
                  }
                },
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
