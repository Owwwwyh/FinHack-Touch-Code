import 'package:drift/drift.dart';
import 'app_db.dart';

class OutboxDao {
  final AppDb _db;
  OutboxDao(this._db);

  Future<List<OutboxData>> getAll() => _db.select(_db.outbox).get();

  Future<List<OutboxData>> getPending({int limit = 50}) {
    return (_db.select(_db.outbox)
          ..where((t) => t.status.equalsValue(TxStatus.pendingSettlement))
          ..limit(limit))
        .get();
  }

  Future<void> insert(OutboxCompanion entry) => _db.into(_db.outbox).insert(entry);

  Future<void> updateStatus(String txId, TxStatus status, {String? rejectReason}) {
    return (_db.update(_db.outbox)..where((t) => t.txId.equals(txId))).write(
      OutboxCompanion(
        status: Value(status),
        rejectReason: Value(rejectReason),
      ),
    );
  }

  Future<void> applyResults(List<Map<String, dynamic>> results) async {
    for (final r in results) {
      final txId = r['tx_id'] as String;
      final status = r['status'] as String;
      if (status == 'SETTLED') {
        await updateStatus(txId, TxStatus.settled);
      } else {
        await updateStatus(txId, TxStatus.rejected, rejectReason: r['reason'] as String?);
      }
    }
  }

  Future<int> pendingCount() async {
    final rows = await getPending();
    return rows.length;
  }
}
