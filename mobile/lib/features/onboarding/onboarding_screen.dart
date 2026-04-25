import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _icLast4Controller = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _icLast4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your offline wallet')),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildPhoneStep(),
          _buildKycStep(),
          _buildKeyGenStep(),
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 1 of 3', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          const Text('Enter your phone number', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+60 12-345 6789',
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 16),
          const Text('We\'ll send an OTP to verify your number.', style: TextStyle(color: Color(0xFF6B7280))),
          const Spacer(),
          FilledButton(
            onPressed: () {
              // Stub: skip OTP verification
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              setState(() => _step = 1);
            },
            child: const Text('Send OTP'),
          ),
        ],
      ),
    );
  }

  Widget _buildKycStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 2 of 3', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          const Text('KYC Tier 1', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _icLast4Controller,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'IC last 4 digits',
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              setState(() => _step = 2);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyGenStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 3 of 3', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 12),
          const Text('Generate your signing key', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text(
            'An Ed25519 key will be generated in your device\'s secure hardware. '
            'This key signs your offline payments and cannot be extracted.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(Icons.vpn_key, size: 56, color: Color(0xFF16A34A)),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: () async {
              // TODO: Call NativeKeystore.ensureKey() and register device
              if (context.mounted) context.go('/home');
            },
            child: const Text('Generate Key & Start'),
          ),
        ],
      ),
    );
  }
}
