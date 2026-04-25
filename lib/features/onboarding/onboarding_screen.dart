import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offline Wallet Setup')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phase 1 onboarding',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const Text(
                'This scaffold prepares the MVP flow described in docs:'),
            const SizedBox(height: 8),
            const Text('1. Cache latest balance for confidence window checks'),
            const Text('2. Switch to AI safe balance when confidence drops'),
            const Text('3. Route to offline pay/receive placeholders'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(RoutePaths.home),
                child: const Text('Continue to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
