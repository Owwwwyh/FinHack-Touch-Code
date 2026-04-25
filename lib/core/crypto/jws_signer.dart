import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// JWS (JSON Web Signature) compact serialization signer and verifier
/// Implements RFC 7515 with Ed25519 (EdDSA) algorithm
///
/// Format: BASE64URL(header).BASE64URL(payload).BASE64URL(signature)
class JwsSigner {
  static const String _algorithm = 'EdDSA';
  static const String _type = 'tng-offline-tx+jws';
  static const String _version = '1';

  final SimplePublicKey _publicKey;
  final SimplePrivateKey _privateKey;
  final String _kid;
  final String _policy;

  /// Creates a JWS signer with a private key
  ///
  /// [privateKeyBytes]: 32-byte Ed25519 private key
  /// [publicKeyBytes]: 32-byte Ed25519 public key (for verification)
  /// [kid]: Key ID, typically a device identifier (UUIDv7)
  /// [policy]: Policy version string (e.g., "v3.2026-04-22")
  JwsSigner({
    required Uint8List privateKeyBytes,
    required Uint8List publicKeyBytes,
    required String kid,
    required String policy,
  })  : _kid = kid,
        _policy = policy,
        _privateKey = SimplePrivateKey(privateKeyBytes),
        _publicKey = SimplePublicKey(publicKeyBytes);

  /// Signs a payload and returns a compact JWS string
  ///
  /// [payload]: Map containing transaction data
  /// Returns: "header.payload.signature" compact JWS format
  Future<String> sign(Map<String, dynamic> payload) async {
    // Build header
    final header = {
      'alg': _algorithm,
      'typ': _type,
      'kid': _kid,
      'policy': _policy,
      'ver': _version,
    };

    // Encode header and payload
    final headerJson = jsonEncode(header);
    final payloadJson = jsonEncode(payload);

    final headerB64 = _base64urlEncode(headerJson);
    final payloadB64 = _base64urlEncode(payloadJson);

    // Message to sign: "header.payload"
    final message = '$headerB64.$payloadB64';

    // Sign using Ed25519
    final ed25519 = Ed25519();
    final signature = await ed25519.sign(
      utf8.encode(message),
      keyPair: SimpleKeyPairData(
        _privateKey.bytes,
        publicKey: _publicKey,
        type: KeyPairType.ed25519,
      ),
    );

    // Encode signature
    final signatureB64 = _base64urlEncode(signature.bytes);

    // Return compact JWS
    return '$message.$signatureB64';
  }

  /// Verifies a compact JWS and extracts the payload
  ///
  /// [jws]: Compact JWS string ("header.payload.signature")
  /// Returns: {valid: bool, payload: Map, error: String?}
  Future<Map<String, dynamic>> verify(String jws) async {
    try {
      // Split JWS into 3 parts
      final parts = jws.split('.');
      if (parts.length != 3) {
        return {
          'valid': false,
          'error': 'INVALID_FORMAT',
          'message': 'JWS must have exactly 3 parts (header.payload.signature)'
        };
      }

      final headerB64 = parts[0];
      final payloadB64 = parts[1];
      final signatureB64 = parts[2];

      // Decode and parse header
      Map<String, dynamic> header;
      try {
        final headerJson = utf8.decode(_base64urlDecode(headerB64));
        header = jsonDecode(headerJson) as Map<String, dynamic>;
      } catch (e) {
        return {
          'valid': false,
          'error': 'INVALID_HEADER',
          'message': e.toString()
        };
      }

      // Validate header fields
      if (header['alg'] != _algorithm) {
        return {
          'valid': false,
          'error': 'INVALID_ALG',
          'message': 'alg must be $_algorithm'
        };
      }
      if (header['typ'] != _type) {
        return {
          'valid': false,
          'error': 'INVALID_TYP',
          'message': 'typ must be $_type'
        };
      }
      if (header['kid'] == null) {
        return {
          'valid': false,
          'error': 'MISSING_KID',
          'message': 'kid is required'
        };
      }

      // Decode and parse payload
      Map<String, dynamic> payload;
      try {
        final payloadJson = utf8.decode(_base64urlDecode(payloadB64));
        payload = jsonDecode(payloadJson) as Map<String, dynamic>;
      } catch (e) {
        return {
          'valid': false,
          'error': 'INVALID_PAYLOAD',
          'message': e.toString()
        };
      }

      // Validate required payload fields
      final requiredFields = [
        'tx_id',
        'sender',
        'receiver',
        'amount',
        'nonce',
        'iat',
        'exp'
      ];
      for (final field in requiredFields) {
        if (payload[field] == null) {
          return {
            'valid': false,
            'error': 'MISSING_FIELD',
            'message': 'payload.$field is required'
          };
        }
      }

      // Check expiration
      final exp = payload['exp'] as int?;
      if (exp == null) {
        return {
          'valid': false,
          'error': 'MISSING_EXP',
          'message': 'exp is required'
        };
      }
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (nowSeconds > exp) {
        return {
          'valid': false,
          'error': 'EXPIRED_TOKEN',
          'message': 'Token expired at $exp, now $nowSeconds'
        };
      }

      // Decode signature
      Uint8List signature;
      try {
        signature = _base64urlDecode(signatureB64);
      } catch (e) {
        return {
          'valid': false,
          'error': 'INVALID_SIGNATURE',
          'message': e.toString()
        };
      }

      // Verify signature
      if (signature.length != 64) {
        return {
          'valid': false,
          'error': 'BAD_SIGNATURE',
          'message': 'Ed25519 signature must be 64 bytes'
        };
      }

      final message = '$headerB64.$payloadB64';
      final ed25519 = Ed25519();

      try {
        final isValid = await ed25519.verify(
          utf8.encode(message),
          signature: Signature(signature, publicKey: _publicKey),
        );

        if (!isValid) {
          return {
            'valid': false,
            'error': 'BAD_SIGNATURE',
            'message': 'Signature verification failed'
          };
        }
      } catch (e) {
        return {
          'valid': false,
          'error': 'VERIFY_ERROR',
          'message': e.toString()
        };
      }

      return {'valid': true, 'payload': payload};
    } catch (e) {
      return {
        'valid': false,
        'error': 'UNKNOWN_ERROR',
        'message': e.toString()
      };
    }
  }

  /// Base64URL encode (no padding)
  static String _base64urlEncode(dynamic input) {
    late Uint8List bytes;
    if (input is String) {
      bytes = utf8.encode(input);
    } else if (input is Uint8List) {
      bytes = input;
    } else {
      throw ArgumentError('Input must be String or Uint8List');
    }

    final encoded = base64Url.encode(bytes);
    // Remove padding
    return encoded.replaceAll('=', '');
  }

  /// Base64URL decode (handles missing padding)
  static Uint8List _base64urlDecode(String input) {
    // Add padding if needed
    String padded = input;
    final remainder = input.length % 4;
    if (remainder != 0) {
      padded = input + ('=' * (4 - remainder));
    }
    return base64Url.decode(padded);
  }
}
