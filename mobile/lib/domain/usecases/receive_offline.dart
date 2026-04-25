import 'package:drift/drift.dart';
import '../../core/result.dart';
import '../../data/db/app_db.dart';

class ReceiveOffline {
  final InboxDao inboxDao;

  ReceiveOffline({required this.inboxDao});

  Future<Result<InboxData>> acceptToken({
    required String txId,
    required String jws,
    required int amountCents,
    required String senderKid,
  }) async {
    try {
      final row = InboxCompanion.insert(
        txId: txId,
        jws: jws,
        amountCents: Value(amountCents),
        senderKid: Value(senderKid),
        receivedAt: Value(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        status: Value(TxStatus.pendingSettlement),
      );
      await inboxDao.insert(row);

      return Result.ok(await inboxDao.getAll().then(
        (list) => list.firstWhere((r) => r.txId == txId),
      ));
    } catch (e) {
      return Result.error(Exception('Receive failed: $e'));
    }
  }
}
