import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'native_keystore.dart';

/// Builds and signs JWS tokens using the Android Keystore via [NativeKeystore].
/// The Ed25519 private key never leaves the Keystore — only the signing input
/// (base64url header + "." + base64url payload) is passed to the native layer.
class NativeJwsSigner {
  static const _algorithm = 'EdDSA';
  static const _typ = 'tng-offline-tx+jws';
  static const _ver = 1;
  static const _defaultAlias = 'tng_signing_v1';

  final String kid;
  final String policy;
  final Uint8List senderPub;
  final String alias;

  NativeJwsSigner({
    required this.kid,
    required this.policy,
    required this.senderPub,
    this.alias = _defaultAlias,
  });

  /// Signs a payment transaction and returns a compact JWS string.
  Future<String> signTransaction({
    required String txId,
    required String userId,
    required String receiverKid,
    required Uint8List receiverPub,
    required int amountCents,
    required String policySignedBalance,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final header = {
      'alg': _algorithm,
      'typ': _typ,
      'kid': kid,
      'policy': policy,
      'ver': _ver,
    };

    final payload = {
      'tx_id': txId,
      'sender': {
        'kid': kid,
        'user_id': userId,
        'pub': _b64url(senderPub),
      },
      'receiver': {
        'kid': receiverKid,
        'user_id': 'unknown',
        'pub': _b64url(receiverPub),
      },
      'amount': {
        'value': (amountCents / 100.0).toStringAsFixed(2),
        'currency': 'MYR',
        'scale': 2,
      },
      'nonce': _generateNonce(),
      'iat': now,
      'exp': now + 72 * 3600,
      'policy_signed_balance': policySignedBalance,
    };

    final headerB64 = _encodeJson(header);
    final payloadB64 = _encodeJson(payload);
    final signingInput = '$headerB64.$payloadB64';

    final sigBytes = await NativeKeystore.sign(
      alias,
      Uint8List.fromList(utf8.encode(signingInput)),
    );

    return '$signingInput.${_b64url(sigBytes)}';
  }

  static String _generateNonce() {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    return _b64url(bytes);
  }

  static String _encodeJson(Map<String, dynamic> map) {
    return _b64url(Uint8List.fromList(utf8.encode(jsonEncode(map))));
  }

  static String _b64url(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
