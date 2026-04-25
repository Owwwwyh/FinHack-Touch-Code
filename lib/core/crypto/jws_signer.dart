// lib/core/crypto/jws_signer.dart
//
// Constructs and signs JWS compact tokens as per docs/03-token-protocol.md §3.
// Signing is delegated to NativeKeystore (Android Keystore via MethodChannel).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'native_keystore.dart';

class JwsSigner {
  JwsSigner({
    required this.kid,
    required this.userId,
    required this.policyVersion,
  });

  final String kid;
  final String userId;
  final String policyVersion;

  static const _uuid = Uuid();

  // ─── Base64URL ─────────────────────────────────────────────────────────────

  static String _b64url(Uint8List bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static String _b64urlStr(String s) => _b64url(utf8.encode(s));

  static Uint8List _randomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Build and sign a JWS for an offline payment.
  ///
  /// [amountMyr]        — decimal string, e.g. "8.50"
  /// [senderPubBytes]   — 32-byte Ed25519 pub key of sender
  /// [receiverKid]      — receiver device key id
  /// [receiverPubBytes] — 32-byte Ed25519 pub key of receiver (from NFC exchange)
  /// [policySignedBalance] — sender's safe_offline_balance at signing time (auditable)
  /// [validityHours]    — default 72 per spec
  Future<String> sign({
    required String amountMyr,
    required Uint8List senderPubBytes,
    required String receiverKid,
    required Uint8List receiverPubBytes,
    required String policySignedBalance,
    int validityHours = 72,
    double? geoLat,
    double? geoLon,
  }) async {
    final iat = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = iat + validityHours * 3600;
    final nonce = _b64url(_randomBytes(16));
    final txId = _uuid.v7();

    // ── Header ──────────────────────────────────────────────────────────────
    final header = {
      'alg':    'EdDSA',
      'typ':    'tng-offline-tx+jws',
      'kid':    kid,
      'policy': policyVersion,
      'ver':    1,
    };

    // ── Payload ─────────────────────────────────────────────────────────────
    final payload = <String, dynamic>{
      'tx_id': txId,
      'sender': {
        'kid':     kid,
        'user_id': userId,
        'pub':     _b64url(senderPubBytes),
      },
      'receiver': {
        'kid':     receiverKid,
        'user_id': 'UNKNOWN', // filled at settlement from server lookup
        'pub':     _b64url(receiverPubBytes),
      },
      'amount': {
        'value':    amountMyr,
        'currency': 'MYR',
        'scale':    2,
      },
      'nonce': nonce,
      'iat':   iat,
      'exp':   exp,
      'policy_signed_balance': policySignedBalance,
    };

    if (geoLat != null && geoLon != null) {
      payload['geo'] = {'lat': geoLat, 'lon': geoLon, 'acc_m': 50};
    }

    // ── Compact JWS ─────────────────────────────────────────────────────────
    final headerB64  = _b64urlStr(jsonEncode(header));
    final payloadB64 = _b64urlStr(jsonEncode(payload));
    final signingInput = '$headerB64.$payloadB64';

    // Sign via Android Keystore (private key stays in TEE)
    final sigBytes = await NativeKeystore.sign(
      Uint8List.fromList(utf8.encode(signingInput)),
    );

    return '$signingInput.${_b64url(sigBytes)}';
  }
}
