import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../core/crypto/jws_signer.dart';
import '../../core/nfc/nfc_session.dart';
import '../../core/result.dart';
import '../../data/db/app_db.dart';

class InsufficientSafeBalance implements Exception {}

class PayOffline {
  final JwsSigner jwsSigner;
  final NfcSession nfcSession;
  final OutboxDao outboxDao;

  PayOffline({
    required this.jwsSigner,
    required this.nfcSession,
    required this.outboxDao,
  });

  Future<Result<OutboxData>> call({
    required int amountCents,
    required int safeOfflineBalanceCents,
    required String senderKid,
    required String senderUserId,
    required String policyVersion,
    required String policySignedBalance,
    Duration tapTimeout = const Duration(seconds: 30),
  }) async {
    if (amountCents > safeOfflineBalanceCents) {
      return Result.error(InsufficientSafeBalance());
    }

    try {
      // Phase A+B: SELECT AID and get receiver pub
      final receiverPub = await nfcSession.selectAid();
      final receiverKid = 'unknown'; // Will be extracted from APDU in full impl

      // Build token
      final txId = const Uuid().v7();
      final now = DateTime.now();
      final nonce = const Uuid().v4();
      final amountMyr = (amountCents / 100).toStringAsFixed(2);

      // Sign JWS
      final jws = await jwsSigner.signToken(
        txId: txId,
        senderKid: senderKid,
        senderUserId: senderUserId,
        receiverKid: receiverKid,
        receiverUserId: '',
        receiverPub: receiverPub,
        amountValue: amountMyr,
        currency: 'MYR',
        amountScale: 2,
        iat: now.millisecondsSinceEpoch ~/ 1000,
        exp: now.add(const Duration(hours: 72)).millisecondsSinceEpoch ~/ 1000,
        nonce: nonce,
        policyVersion: policyVersion,
        policySignedBalance: policySignedBalance,
      );

      // Phase C+D: Send JWS chunks and get ack
      final ack = await nfcSession.sendChunks(jws, timeout: tapTimeout);

      // Save to outbox
      final row = OutboxCompanion.insert(
        txId: txId,
        jws: jws,
        amountCents: Value(amountCents),
        receiverKid: Value(receiverKid),
        createdAt: Value(now.millisecondsSinceEpoch ~/ 1000),
        status: Value(TxStatus.pendingSettlement),
        ackSig: Value(String.fromCharCodes(ack)),
      );
      await outboxDao.insert(row);

      // Decrement safe offline balance locally
      // This is handled by the caller updating state

      return Result.ok(await outboxDao.getAll().then(
        (list) => list.firstWhere((r) => r.txId == txId),
      ));
    } catch (e) {
      return Result.error(Exception('Payment failed: $e'));
    }
  }
}
