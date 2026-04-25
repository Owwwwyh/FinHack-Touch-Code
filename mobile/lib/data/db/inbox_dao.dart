import 'package:drift/drift.dart';
import 'app_db.dart';

class InboxDao {
  final AppDb _db;
  InboxDao(this._db);

  Future<List<InboxData>> getAll() => _db.select(_db.inbox).get();

  Future<void> insert(InboxCompanion entry) => _db.into(_db.inbox).insert(entry);

  Future<void> updateStatus(String txId, TxStatus status) {
    return (_db.update(_db.inbox)..where((t) => t.txId.equals(txId))).write(
      InboxCompanion(status: Value(status)),
    );
  }

  Future<int> pendingCount() async {
    final rows = await (_db.select(_db.inbox)
          ..where((t) => t.status.equalsValue(TxStatus.pendingSettlement)))
        .get();
    return rows.length;
  }
}
