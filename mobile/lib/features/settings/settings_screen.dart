import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Device info
          const _SectionHeader('Device'),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Device Key ID'),
            subtitle: const Text('did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Attestation'),
            subtitle: const Text('Valid · StrongBox backed'),
            trailing: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          ),
          const Divider(),
          // Policy
          const _SectionHeader('Policy'),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('Policy Version'),
            subtitle: const Text('v3.2026-04-22'),
          ),
          ListTile(
            leading: const Icon(Icons.model_training),
            title: const Text('Model Version'),
            subtitle: const Text('credit-v3.tflite'),
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Key Rotation'),
            subtitle: const Text('Last rotated: never'),
            onTap: () {
              // TODO: Trigger key rotation
            },
          ),
          const Divider(),
          // Account
          const _SectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('KYC Tier'),
            subtitle: const Text('Tier 1'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () {
              // TODO: Sign out flow
            },
          ),
          const Divider(),
          // About
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('App Version'),
            subtitle: Text('1.0.0+1 (demo)'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B7280))),
    );
  }
}
