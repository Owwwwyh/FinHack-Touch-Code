import 'package:drift/drift.dart';
import 'app_db.dart';

class BalanceCacheDao {
  final AppDb _db;
  BalanceCacheDao(this._db);

  Future<BalanceCacheData?> get(String userId) {
    return (_db.select(_db.balanceCache)..where((t) => t.userId.equals(userId)))
        .getSingleOrNull();
  }

  Future<void> upsert({
    required String userId,
    required int balanceCents,
    required int safeOfflineCents,
    required int syncedAt,
    required String policyVersion,
  }) {
    return _db.into(_db.balanceCache).insertOnConflictUpdate(
          BalanceCacheCompanion.insert(
            userId: userId,
            balanceCents: Value(balanceCents),
            safeOfflineCents: Value(safeOfflineCents),
            syncedAt: Value(syncedAt),
            policyVersion: Value(policyVersion),
          ),
        );
  }

  Future<void> updateSafeOffline(String userId, int safeOfflineCents) {
    return (_db.update(_db.balanceCache)..where((t) => t.userId.equals(userId))).write(
      BalanceCacheCompanion(safeOfflineCents: Value(safeOfflineCents)),
    );
  }
}
