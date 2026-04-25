import 'dart:math';
import 'dart:typed_data';

import '../../domain/models/payment_request.dart';
import '../../domain/services/offline_pay_policy.dart';
import 'native_jws_signer.dart';
import 'native_keystore.dart';

class DeviceIdentity {
  const DeviceIdentity({
    required this.kid,
    required this.publicKey,
  });

  final String kid;
  final Uint8List publicKey;
}

class SignedPaymentToken {
  const SignedPaymentToken({
    required this.txId,
    required this.jws,
    required this.senderKid,
  });

  final String txId;
  final String jws;
  final String senderKid;
}

abstract class OfflineSigningService {
  Future<DeviceIdentity> ensureIdentity();

  Future<SignedPaymentToken> signPayment({
    required PaymentRequest request,
    required OfflinePayPolicy policy,
  });
}

class NativeOfflineSigningService implements OfflineSigningService {
  static const _alias = 'tng_signing_v1';

  @override
  Future<DeviceIdentity> ensureIdentity() async {
    if (!await NativeKeystore.keyExists(_alias)) {
      await NativeKeystore.generateKey(_alias, Uint8List(0));
    }

    final publicKey = await NativeKeystore.getPublicKey(_alias);
    return DeviceIdentity(
      kid: _deriveKid(publicKey),
      publicKey: publicKey,
    );
  }

  @override
  Future<SignedPaymentToken> signPayment({
    required PaymentRequest request,
    required OfflinePayPolicy policy,
  }) async {
    final identity = await ensureIdentity();
    final txId = _generateTxId();
    final signer = NativeJwsSigner(
      kid: identity.kid,
      policy: policy.policyVersion,
      senderPub: identity.publicKey,
    );

    final jws = await signer.signTransaction(
      txId: txId,
      userId: 'local_user',
      receiverKid: request.receiver.kid,
      receiverPub: request.receiver.publicKey,
      amountCents: request.amountCents,
      policySignedBalance:
          (policy.safeOfflineBalanceCents / 100).toStringAsFixed(2),
    );

    return SignedPaymentToken(
      txId: txId,
      jws: jws,
      senderKid: identity.kid,
    );
  }

  String _deriveKid(Uint8List publicKey) {
    final buffer = StringBuffer();
    for (final byte in publicKey.take(13)) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return 'did:tng:device:${buffer.toString().toUpperCase()}';
  }

  String _generateTxId() {
    const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    final random = Random.secure();
    final now =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final suffix = List.generate(
      10,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return '01${now.padLeft(10, '0')}$suffix';
  }
}
