import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tng_clone_flutter/core/crypto/jws_signer.dart';

void main() {
  group('JwsSigner', () {
    late JwsSigner signer;
    late String kid;
    late String policy;

    setUp(() async {
      // Generate a real Ed25519 keypair so sign+verify roundtrips work.
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final keyPairData = await keyPair.extract();
      final publicKey = await keyPairData.extractPublicKey();
      final privateKeyBytes = Uint8List.fromList(keyPairData.bytes);
      final publicKeyBytes = Uint8List.fromList(publicKey.bytes);

      kid = 'did:tng:device:01HW3YKQ8X2A5FR7JM6T1EE9NP';
      policy = 'v3.2026-04-22';

      signer = JwsSigner(
        privateKeyBytes: privateKeyBytes,
        publicKeyBytes: publicKeyBytes,
        kid: kid,
        policy: policy,
      );
    });

    test('roundtrip: sign and verify returns same payload', () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = iat + 72 * 3600;
      final payload = {
        'tx_id': '01HW3YKQ8X2A5FR7JM6T1EE9NP',
        'sender': {
          'kid': kid,
          'user_id': 'u_8412',
          'pub': 'BASE64URL(32 bytes)',
        },
        'receiver': {
          'kid': 'did:tng:device:01HW4YKQ8X2A5FR7JM6T1EE9NQ',
          'user_id': 'u_3091',
          'pub': 'BASE64URL(32 bytes)',
        },
        'amount': {'value': '8.50', 'currency': 'MYR', 'scale': 2},
        'nonce': 'BASE64URL(16 bytes)',
        'iat': iat,
        'exp': exp,
        'policy_signed_balance': '120.00'
      };

      final jws = await signer.sign(payload);

      expect(jws, isNotEmpty);
      expect(jws.split('.').length, equals(3));

      final result = await signer.verify(jws);

      expect(result['valid'], isTrue);
      expect(result['payload'], isNotNull);
      final verifiedPayload = result['payload'] as Map<String, dynamic>;
      expect(verifiedPayload['tx_id'], equals(payload['tx_id']));
      expect(verifiedPayload['amount'], equals(payload['amount']));
    });

    test('verify rejects tampered signature', () async {
      final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = iat + 72 * 3600;
      final payload = {
        'tx_id': '01HW3YKQ8X2A5FR7JM6T1EE9NP',
        'sender': {'kid': kid, 'user_id': 'u_8412', 'pub': 'test'},
        'receiver': {
          'kid': 'did:tng:device:01HW4',
          'user_id': 'u_3091',
          'pub': 'test'
        },
        'amount': {'value': '8.50', 'currency': 'MYR', 'scale': 2},
        'nonce': 'random_nonce',
        'iat': iat,
        'exp': exp,
        'policy_signed_balance': '120.00'
      };

      final jws = await signer.sign(payload);
      final parts = jws.split('.');

      // Corrupt the signature
      final corruptedSig = parts[2].replaceFirst(parts[2][0], 'Z');
      final corruptedJws = '${parts[0]}.${parts[1]}.$corruptedSig';

      final result = await signer.verify(corruptedJws);

      expect(result['valid'], isFalse);
      expect(result['error'], equals('BAD_SIGNATURE'));
    });

    test('verify rejects expired token', () async {
      final payload = {
        'tx_id': '01HW3YKQ8X2A5FR7JM6T1EE9NP',
        'sender': {'kid': kid, 'user_id': 'u_8412', 'pub': 'test'},
        'receiver': {
          'kid': 'did:tng:device:01HW4',
          'user_id': 'u_3091',
          'pub': 'test'
        },
        'amount': {'value': '8.50', 'currency': 'MYR', 'scale': 2},
        'nonce': 'random_nonce',
        'iat': 1000000000, // Past timestamp
        'exp': 1000000001, // Also in past
        'policy_signed_balance': '120.00'
      };

      final jws = await signer.sign(payload);
      final result = await signer.verify(jws);

      expect(result['valid'], isFalse);
      expect(result['error'], equals('EXPIRED_TOKEN'));
    });

    test('verify rejects missing required fields', () async {
      final payload = {
        'tx_id': '01HW3YKQ8X2A5FR7JM6T1EE9NP',
        'sender': {'kid': kid},
        // Missing 'receiver'
        'amount': {'value': '8.50'},
        'nonce': 'random_nonce',
        'iat': 1745603421,
        'exp': 1745862621,
      };

      final jws = await signer.sign(payload);
      final result = await signer.verify(jws);

      expect(result['valid'], isFalse);
      expect(result['error'], equals('MISSING_FIELD'));
    });

    test('verify rejects malformed JWS (wrong number of parts)', () async {
      final malformed = 'header.payload'; // Missing signature part

      final result = await signer.verify(malformed);

      expect(result['valid'], isFalse);
      expect(result['error'], equals('INVALID_FORMAT'));
    });

    test('sign produces compact JWS format', () async {
      final payload = {
        'tx_id': 'test-tx-001',
        'sender': {'kid': kid, 'user_id': 'u_8412', 'pub': 'test'},
        'receiver': {'kid': 'device-2', 'user_id': 'u_3091', 'pub': 'test'},
        'amount': {'value': '50.00', 'currency': 'MYR', 'scale': 2},
        'nonce': 'test-nonce-123',
        'iat': 1745603421,
        'exp': 1745862621,
        'policy_signed_balance': '200.00'
      };

      final jws = await signer.sign(payload);

      // JWS must be three dot-separated base64url strings
      final parts = jws.split('.');
      expect(parts.length, equals(3));

      // Each part should be valid base64url (no padding, only [A-Za-z0-9_-])
      for (final part in parts) {
        expect(part, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      }

      // Signature must be 88 chars (64 bytes base64url)
      expect(parts[2].length, greaterThan(80));
    });
  });
}
