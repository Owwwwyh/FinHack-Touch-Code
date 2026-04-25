// lib/data/db/app_db.dart
//
// Drift database definition — exact schema from docs/07-mobile-app.md §8.
// Tables: Outbox, Inbox, BalanceCache
//
// Generate code with:
//   dart run build_runner build --delete-conflicting-outputs

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_db.g.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum TxStatus {
  pendingNfc,          // Sender: NFC exchange in progress
  pendingSettlement,   // Waiting to post to /tokens/settle
  settled,             // Backend confirmed settled
  rejected,            // Backend rejected (nonce_reused, expired, bad_sig, etc.)
}

// ─── Tables ───────────────────────────────────────────────────────────────────

/// Sender's outbox — tokens they've signed and sent over NFC.
@DataClassName('OutboxRow')
class Outbox extends Table {
  TextColumn get txId        => text()();
  TextColumn get jws         => text()();                          // compact JWS string
  IntColumn  get amountCents => integer()();                       // MYR * 100
  TextColumn get receiverKid => text()();
  IntColumn  get createdAt   => integer()();                       // unix seconds
  IntColumn  get status      => intEnum<TxStatus>()();
  TextColumn get rejectReason => text().nullable()();
  TextColumn get ackSig      => text().nullable()();               // receiver ack-sig (base64url)
  IntColumn  get attemptCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {txId};
}

/// Receiver's inbox — tokens received over NFC from others.
@DataClassName('InboxRow')
class Inbox extends Table {
  TextColumn get txId        => text()();
  TextColumn get jws         => text()();
  IntColumn  get amountCents => integer()();
  TextColumn get senderKid   => text()();
  IntColumn  get receivedAt  => integer()();
  IntColumn  get status      => intEnum<TxStatus>()();
  TextColumn get rejectReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {txId};
}

/// Cached server balance — used to display balance and compute safe_offline.
@DataClassName('BalanceCacheRow')
class BalanceCache extends Table {
  TextColumn get userId            => text()();
  IntColumn  get balanceCents      => integer()();           // MYR * 100
  IntColumn  get safeOfflineCents  => integer()();           // MYR * 100
  IntColumn  get syncedAt          => integer()();           // unix seconds
  TextColumn get policyVersion     => text()();

  @override
  Set<Column> get primaryKey => {userId};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [Outbox, Inbox, BalanceCache])
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'tng_wallet');
  }
}

// ─── Outbox DAO ────────────────────────────────────────────────────────────────

extension OutboxDao on AppDb {
  /// Insert a new outbox entry (status = pendingSettlement).
  Future<void> insertOutbox(OutboxRow row) =>
      into(outbox).insertOnConflictUpdate(row);

  /// Return all PENDING_SETTLEMENT rows, oldest first, up to [limit].
  Future<List<OutboxRow>> takePending({int limit = 50}) =>
      (select(outbox)
            ..where((t) => t.status.equals(TxStatus.pendingSettlement.index))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(limit))
          .get();

  /// Mark a token as SETTLED.
  Future<void> markSettled(String txId) =>
      (update(outbox)..where((t) => t.txId.equals(txId))).write(
        const OutboxCompanion(status: Value(TxStatus.settled)),
      );

  /// Mark a token as REJECTED with a reason.
  Future<void> markRejected(String txId, String reason) =>
      (update(outbox)..where((t) => t.txId.equals(txId))).write(
        OutboxCompanion(
          status:       const Value(TxStatus.rejected),
          rejectReason: Value(reason),
        ),
      );

  /// Get all settled/rejected entries for history display.
  Future<List<OutboxRow>> getHistory() =>
      (select(outbox)
            ..where((t) =>
                t.status.equals(TxStatus.settled.index) |
                t.status.equals(TxStatus.rejected.index))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Watch pending count for the badge.
  Stream<int> watchPendingCount() =>
      (selectOnly(outbox)
            ..addColumns([outbox.txId.count()])
            ..where(outbox.status.equals(TxStatus.pendingSettlement.index)))
          .map((r) => r.read(outbox.txId.count()) ?? 0)
          .watchSingle();
}

// ─── Inbox DAO ─────────────────────────────────────────────────────────────────

extension InboxDao on AppDb {
  Future<void> insertInbox(InboxRow row) =>
      into(inbox).insertOnConflictUpdate(row);

  Future<List<InboxRow>> getPendingInbox() =>
      (select(inbox)
            ..where((t) => t.status.equals(TxStatus.pendingSettlement.index)))
          .get();

  Future<void> markInboxSettled(String txId) =>
      (update(inbox)..where((t) => t.txId.equals(txId))).write(
        const InboxCompanion(status: Value(TxStatus.settled)),
      );

  Future<List<InboxRow>> getInboxHistory() =>
      (select(inbox)
            ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
          .get();
}

// ─── Balance Cache DAO ─────────────────────────────────────────────────────────

extension BalanceCacheDao on AppDb {
  Future<void> upsertBalance(BalanceCacheRow row) =>
      into(balanceCache).insertOnConflictUpdate(row);

  Future<BalanceCacheRow?> getBalance(String userId) =>
      (select(balanceCache)..where((t) => t.userId.equals(userId)))
          .getSingleOrNull();

  /// Watch balance for reactive UI updates.
  Stream<BalanceCacheRow?> watchBalance(String userId) =>
      (select(balanceCache)..where((t) => t.userId.equals(userId)))
          .watchSingleOrNull();
}
