// lib/data/api/devices_api.dart
import 'dart:async';

class DevicesApi {
  /// Mock registering a device public key.
  Future<String> registerDevice({
    required String userId,
    required String publicKeyBase64,
    required List<String> attestationChain,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Returns a mock device KID
    return 'did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP';
  }
}
