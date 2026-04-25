import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart' as crypto;
import 'native_keystore.dart';

/// JWS Compact Serialization signer for Ed25519 tokens.
/// Format: BASE64URL(header).BASE64URL(payload).BASE64URL(signature)
class JwsSigner {
  final NativeKeystore keystore;

  JwsSigner({required this.keystore});

  static const _headerAlg = 'EdDSA';
  static const _headerTyp = 'tng-offline-tx+jws';

  /// Build and sign a JWS token for an offline payment.
  Future<String> signToken({
    required String txId,
    required String senderKid,
    required String senderUserId,
    required String receiverKid,
    required String receiverUserId,
    required Uint8List receiverPub,
    required String amountValue,
    required String currency,
    required int amountScale,
    required int iat,
    required int exp,
    required String nonce,
    required String policyVersion,
    String? policySignedBalance,
    Map<String, dynamic>? geo,
  }) async {
    final header = {
      'alg': _headerAlg,
      'typ': _headerTyp,
      'kid': 'did:tng:device:$senderKid',
      'policy': policyVersion,
      'ver': 1,
    };

    final senderPub = await keystore.getPublicKey();
    final senderPubB64 = base64UrlEncode(senderPub);

    final payload = {
      'tx_id': txId,
      'sender': {
        'kid': 'did:tng:device:$senderKid',
        'user_id': senderUserId,
        'pub': senderPubB64,
      },
      'receiver': {
        'kid': 'did:tng:device:$receiverKid',
        'user_id': receiverUserId,
        'pub': base64UrlEncode(receiverPub),
      },
      'amount': {
        'value': amountValue,
        'currency': currency,
        'scale': amountScale,
      },
      'nonce': base64UrlEncode(Uint8List.fromList(nonce.codeUnits)),
      'iat': iat,
      'exp': exp,
      if (geo != null) 'geo': geo,
      if (policySignedBalance != null)
        'policy_signed_balance': policySignedBalance,
    };

    final headerB64 = base64UrlEncode(utf8.encode(jsonEncode(header)));
    final payloadB64 = base64UrlEncode(utf8.encode(jsonEncode(payload)));
    final signingInput = '$headerB64.$payloadB64';

    final sigBytes = await keystore.sign(Uint8List.fromList(utf8.encode(signingInput)));
    final sigB64 = base64UrlEncode(sigBytes);

    return '$signingInput.$sigB64';
  }

  /// Verify a JWS token using a provided public key.
  static Future<bool> verify({
    required String jws,
    required Uint8List publicKey,
  }) async {
    final parts = jws.split('.');
    if (parts.length != 3) return false;

    final signingInput = '${parts[0]}.${parts[1]}';
    final signature = base64UrlDecode(parts[2]);

    final algorithm = crypto.Ed25519();
    final keyPair = crypto.SimpleKeyPairData(
      crypto.SimplePublicKey(publicKey, type: crypto.KeyPairType.ed25519),
      crypto.SimplePrivateKey(const [], type: crypto.KeyPairType.ed25519),
      type: crypto.KeyPairType.ed25519,
    );

    try {
      final valid = await algorithm.verify(
        Uint8List.fromList(utf8.encode(signingInput)),
        signature: crypto.Signature(signature),
      );
      return valid;
    } catch (_) {
      return false;
    }
  }

  /// Decode a JWS without verifying.
  static ({Map<String, dynamic> header, Map<String, dynamic> payload, String signature}) decode(String jws) {
    final parts = jws.split('.');
    if (parts.length != 3) throw FormatException('Invalid JWS format');
    final header = jsonDecode(utf8.decode(base64UrlDecode(parts[0]))) as Map<String, dynamic>;
    final payload = jsonDecode(utf8.decode(base64UrlDecode(parts[1]))) as Map<String, dynamic>;
    return (header: header, payload: payload, signature: parts[2]);
  }
}
