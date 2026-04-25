import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'outbox_dao.dart';
import 'inbox_dao.dart';
import 'balance_cache_dao.dart';

part 'app_db.g.dart';

class Outbox extends Table {
  TextColumn get txId => text()();
  TextColumn get jws => text()();
  IntColumn get amountCents => integer()();
  TextColumn get receiverKid => text()();
  IntColumn get createdAt => integer()();
  IntColumn get status => intEnum<TxStatus>()();
  TextColumn get rejectReason => text().nullable()();
  TextColumn get ackSig => text().nullable()();

  @override
  Set<Column> get primaryKey => {txId};
}

class Inbox extends Table {
  TextColumn get txId => text()();
  TextColumn get jws => text()();
  IntColumn get amountCents => integer()();
  TextColumn get senderKid => text()();
  IntColumn get receivedAt => integer()();
  IntColumn get status => intEnum<TxStatus>()();

  @override
  Set<Column> get primaryKey => {txId};
}

class BalanceCache extends Table {
  TextColumn get userId => text()();
  IntColumn get balanceCents => integer()();
  IntColumn get safeOfflineCents => integer()();
  IntColumn get syncedAt => integer()();
  TextColumn get policyVersion => text()();

  @override
  Set<Column> get primaryKey => {userId};
}

enum TxStatus {
  pendingNfc,
  pendingSettlement,
  settled,
  rejected,
}

@DriftDatabase(tables: [Outbox, Inbox, BalanceCache])
class AppDb extends _$AppDb {
  AppDb() : super(driftDatabase(name: 'tng_finhack.db'));

  @override
  int get schemaVersion => 1;

  late final outboxDao = OutboxDao(this);
  late final inboxDao = InboxDao(this);
  late final balanceCacheDao = BalanceCacheDao(this);
}
