// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _txIdMeta = const VerificationMeta('txId');
  @override
  late final GeneratedColumn<String> txId = GeneratedColumn<String>(
      'tx_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jwsMeta = const VerificationMeta('jws');
  @override
  late final GeneratedColumn<String> jws = GeneratedColumn<String>(
      'jws', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountCentsMeta =
      const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
      'amount_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _receiverKidMeta =
      const VerificationMeta('receiverKid');
  @override
  late final GeneratedColumn<String> receiverKid = GeneratedColumn<String>(
      'receiver_kid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TxStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TxStatus>($OutboxTable.$converterstatus);
  static const VerificationMeta _rejectReasonMeta =
      const VerificationMeta('rejectReason');
  @override
  late final GeneratedColumn<String> rejectReason = GeneratedColumn<String>(
      'reject_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ackSigMeta = const VerificationMeta('ackSig');
  @override
  late final GeneratedColumn<String> ackSig = GeneratedColumn<String>(
      'ack_sig', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _attemptCountMeta =
      const VerificationMeta('attemptCount');
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
      'attempt_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        txId,
        jws,
        amountCents,
        receiverKid,
        createdAt,
        status,
        rejectReason,
        ackSig,
        attemptCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tx_id')) {
      context.handle(
          _txIdMeta, txId.isAcceptableOrUnknown(data['tx_id']!, _txIdMeta));
    } else if (isInserting) {
      context.missing(_txIdMeta);
    }
    if (data.containsKey('jws')) {
      context.handle(
          _jwsMeta, jws.isAcceptableOrUnknown(data['jws']!, _jwsMeta));
    } else if (isInserting) {
      context.missing(_jwsMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
          _amountCentsMeta,
          amountCents.isAcceptableOrUnknown(
              data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('receiver_kid')) {
      context.handle(
          _receiverKidMeta,
          receiverKid.isAcceptableOrUnknown(
              data['receiver_kid']!, _receiverKidMeta));
    } else if (isInserting) {
      context.missing(_receiverKidMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('reject_reason')) {
      context.handle(
          _rejectReasonMeta,
          rejectReason.isAcceptableOrUnknown(
              data['reject_reason']!, _rejectReasonMeta));
    }
    if (data.containsKey('ack_sig')) {
      context.handle(_ackSigMeta,
          ackSig.isAcceptableOrUnknown(data['ack_sig']!, _ackSigMeta));
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
          _attemptCountMeta,
          attemptCount.isAcceptableOrUnknown(
              data['attempt_count']!, _attemptCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {txId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      txId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tx_id'])!,
      jws: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jws'])!,
      amountCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      receiverKid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}receiver_kid'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      status: $OutboxTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      rejectReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reject_reason']),
      ackSig: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ack_sig']),
      attemptCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempt_count'])!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxStatus, int, int> $converterstatus =
      const EnumIndexConverter<TxStatus>(TxStatus.values);
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String txId;
  final String jws;
  final int amountCents;
  final String receiverKid;
  final int createdAt;
  final TxStatus status;
  final String? rejectReason;
  final String? ackSig;
  final int attemptCount;
  const OutboxRow(
      {required this.txId,
      required this.jws,
      required this.amountCents,
      required this.receiverKid,
      required this.createdAt,
      required this.status,
      this.rejectReason,
      this.ackSig,
      required this.attemptCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tx_id'] = Variable<String>(txId);
    map['jws'] = Variable<String>(jws);
    map['amount_cents'] = Variable<int>(amountCents);
    map['receiver_kid'] = Variable<String>(receiverKid);
    map['created_at'] = Variable<int>(createdAt);
    {
      map['status'] =
          Variable<int>($OutboxTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || rejectReason != null) {
      map['reject_reason'] = Variable<String>(rejectReason);
    }
    if (!nullToAbsent || ackSig != null) {
      map['ack_sig'] = Variable<String>(ackSig);
    }
    map['attempt_count'] = Variable<int>(attemptCount);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      txId: Value(txId),
      jws: Value(jws),
      amountCents: Value(amountCents),
      receiverKid: Value(receiverKid),
      createdAt: Value(createdAt),
      status: Value(status),
      rejectReason: rejectReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectReason),
      ackSig:
          ackSig == null && nullToAbsent ? const Value.absent() : Value(ackSig),
      attemptCount: Value(attemptCount),
    );
  }

  factory OutboxRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      txId: serializer.fromJson<String>(json['txId']),
      jws: serializer.fromJson<String>(json['jws']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      receiverKid: serializer.fromJson<String>(json['receiverKid']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      status: $OutboxTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      rejectReason: serializer.fromJson<String?>(json['rejectReason']),
      ackSig: serializer.fromJson<String?>(json['ackSig']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'txId': serializer.toJson<String>(txId),
      'jws': serializer.toJson<String>(jws),
      'amountCents': serializer.toJson<int>(amountCents),
      'receiverKid': serializer.toJson<String>(receiverKid),
      'createdAt': serializer.toJson<int>(createdAt),
      'status':
          serializer.toJson<int>($OutboxTable.$converterstatus.toJson(status)),
      'rejectReason': serializer.toJson<String?>(rejectReason),
      'ackSig': serializer.toJson<String?>(ackSig),
      'attemptCount': serializer.toJson<int>(attemptCount),
    };
  }

  OutboxRow copyWith(
          {String? txId,
          String? jws,
          int? amountCents,
          String? receiverKid,
          int? createdAt,
          TxStatus? status,
          Value<String?> rejectReason = const Value.absent(),
          Value<String?> ackSig = const Value.absent(),
          int? attemptCount}) =>
      OutboxRow(
        txId: txId ?? this.txId,
        jws: jws ?? this.jws,
        amountCents: amountCents ?? this.amountCents,
        receiverKid: receiverKid ?? this.receiverKid,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        rejectReason:
            rejectReason.present ? rejectReason.value : this.rejectReason,
        ackSig: ackSig.present ? ackSig.value : this.ackSig,
        attemptCount: attemptCount ?? this.attemptCount,
      );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      txId: data.txId.present ? data.txId.value : this.txId,
      jws: data.jws.present ? data.jws.value : this.jws,
      amountCents:
          data.amountCents.present ? data.amountCents.value : this.amountCents,
      receiverKid:
          data.receiverKid.present ? data.receiverKid.value : this.receiverKid,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      rejectReason: data.rejectReason.present
          ? data.rejectReason.value
          : this.rejectReason,
      ackSig: data.ackSig.present ? data.ackSig.value : this.ackSig,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('txId: $txId, ')
          ..write('jws: $jws, ')
          ..write('amountCents: $amountCents, ')
          ..write('receiverKid: $receiverKid, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rejectReason: $rejectReason, ')
          ..write('ackSig: $ackSig, ')
          ..write('attemptCount: $attemptCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(txId, jws, amountCents, receiverKid,
      createdAt, status, rejectReason, ackSig, attemptCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.txId == this.txId &&
          other.jws == this.jws &&
          other.amountCents == this.amountCents &&
          other.receiverKid == this.receiverKid &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.rejectReason == this.rejectReason &&
          other.ackSig == this.ackSig &&
          other.attemptCount == this.attemptCount);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> txId;
  final Value<String> jws;
  final Value<int> amountCents;
  final Value<String> receiverKid;
  final Value<int> createdAt;
  final Value<TxStatus> status;
  final Value<String?> rejectReason;
  final Value<String?> ackSig;
  final Value<int> attemptCount;
  final Value<int> rowid;
  const OutboxCompanion({
    this.txId = const Value.absent(),
    this.jws = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.receiverKid = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rejectReason = const Value.absent(),
    this.ackSig = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String txId,
    required String jws,
    required int amountCents,
    required String receiverKid,
    required int createdAt,
    required TxStatus status,
    this.rejectReason = const Value.absent(),
    this.ackSig = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : txId = Value(txId),
        jws = Value(jws),
        amountCents = Value(amountCents),
        receiverKid = Value(receiverKid),
        createdAt = Value(createdAt),
        status = Value(status);
  static Insertable<OutboxRow> custom({
    Expression<String>? txId,
    Expression<String>? jws,
    Expression<int>? amountCents,
    Expression<String>? receiverKid,
    Expression<int>? createdAt,
    Expression<int>? status,
    Expression<String>? rejectReason,
    Expression<String>? ackSig,
    Expression<int>? attemptCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (txId != null) 'tx_id': txId,
      if (jws != null) 'jws': jws,
      if (amountCents != null) 'amount_cents': amountCents,
      if (receiverKid != null) 'receiver_kid': receiverKid,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (rejectReason != null) 'reject_reason': rejectReason,
      if (ackSig != null) 'ack_sig': ackSig,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith(
      {Value<String>? txId,
      Value<String>? jws,
      Value<int>? amountCents,
      Value<String>? receiverKid,
      Value<int>? createdAt,
      Value<TxStatus>? status,
      Value<String?>? rejectReason,
      Value<String?>? ackSig,
      Value<int>? attemptCount,
      Value<int>? rowid}) {
    return OutboxCompanion(
      txId: txId ?? this.txId,
      jws: jws ?? this.jws,
      amountCents: amountCents ?? this.amountCents,
      receiverKid: receiverKid ?? this.receiverKid,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      ackSig: ackSig ?? this.ackSig,
      attemptCount: attemptCount ?? this.attemptCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (txId.present) {
      map['tx_id'] = Variable<String>(txId.value);
    }
    if (jws.present) {
      map['jws'] = Variable<String>(jws.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (receiverKid.present) {
      map['receiver_kid'] = Variable<String>(receiverKid.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($OutboxTable.$converterstatus.toSql(status.value));
    }
    if (rejectReason.present) {
      map['reject_reason'] = Variable<String>(rejectReason.value);
    }
    if (ackSig.present) {
      map['ack_sig'] = Variable<String>(ackSig.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('txId: $txId, ')
          ..write('jws: $jws, ')
          ..write('amountCents: $amountCents, ')
          ..write('receiverKid: $receiverKid, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('rejectReason: $rejectReason, ')
          ..write('ackSig: $ackSig, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxTable extends Inbox with TableInfo<$InboxTable, InboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _txIdMeta = const VerificationMeta('txId');
  @override
  late final GeneratedColumn<String> txId = GeneratedColumn<String>(
      'tx_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jwsMeta = const VerificationMeta('jws');
  @override
  late final GeneratedColumn<String> jws = GeneratedColumn<String>(
      'jws', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountCentsMeta =
      const VerificationMeta('amountCents');
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
      'amount_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _senderKidMeta =
      const VerificationMeta('senderKid');
  @override
  late final GeneratedColumn<String> senderKid = GeneratedColumn<String>(
      'sender_kid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _receivedAtMeta =
      const VerificationMeta('receivedAt');
  @override
  late final GeneratedColumn<int> receivedAt = GeneratedColumn<int>(
      'received_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<TxStatus, int> status =
      GeneratedColumn<int>('status', aliasedName, false,
              type: DriftSqlType.int, requiredDuringInsert: true)
          .withConverter<TxStatus>($InboxTable.$converterstatus);
  static const VerificationMeta _rejectReasonMeta =
      const VerificationMeta('rejectReason');
  @override
  late final GeneratedColumn<String> rejectReason = GeneratedColumn<String>(
      'reject_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [txId, jws, amountCents, senderKid, receivedAt, status, rejectReason];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox';
  @override
  VerificationContext validateIntegrity(Insertable<InboxRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tx_id')) {
      context.handle(
          _txIdMeta, txId.isAcceptableOrUnknown(data['tx_id']!, _txIdMeta));
    } else if (isInserting) {
      context.missing(_txIdMeta);
    }
    if (data.containsKey('jws')) {
      context.handle(
          _jwsMeta, jws.isAcceptableOrUnknown(data['jws']!, _jwsMeta));
    } else if (isInserting) {
      context.missing(_jwsMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
          _amountCentsMeta,
          amountCents.isAcceptableOrUnknown(
              data['amount_cents']!, _amountCentsMeta));
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('sender_kid')) {
      context.handle(_senderKidMeta,
          senderKid.isAcceptableOrUnknown(data['sender_kid']!, _senderKidMeta));
    } else if (isInserting) {
      context.missing(_senderKidMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
          _receivedAtMeta,
          receivedAt.isAcceptableOrUnknown(
              data['received_at']!, _receivedAtMeta));
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    if (data.containsKey('reject_reason')) {
      context.handle(
          _rejectReasonMeta,
          rejectReason.isAcceptableOrUnknown(
              data['reject_reason']!, _rejectReasonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {txId};
  @override
  InboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxRow(
      txId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tx_id'])!,
      jws: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jws'])!,
      amountCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_cents'])!,
      senderKid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_kid'])!,
      receivedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}received_at'])!,
      status: $InboxTable.$converterstatus.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!),
      rejectReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reject_reason']),
    );
  }

  @override
  $InboxTable createAlias(String alias) {
    return $InboxTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxStatus, int, int> $converterstatus =
      const EnumIndexConverter<TxStatus>(TxStatus.values);
}

class InboxRow extends DataClass implements Insertable<InboxRow> {
  final String txId;
  final String jws;
  final int amountCents;
  final String senderKid;
  final int receivedAt;
  final TxStatus status;
  final String? rejectReason;
  const InboxRow(
      {required this.txId,
      required this.jws,
      required this.amountCents,
      required this.senderKid,
      required this.receivedAt,
      required this.status,
      this.rejectReason});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tx_id'] = Variable<String>(txId);
    map['jws'] = Variable<String>(jws);
    map['amount_cents'] = Variable<int>(amountCents);
    map['sender_kid'] = Variable<String>(senderKid);
    map['received_at'] = Variable<int>(receivedAt);
    {
      map['status'] = Variable<int>($InboxTable.$converterstatus.toSql(status));
    }
    if (!nullToAbsent || rejectReason != null) {
      map['reject_reason'] = Variable<String>(rejectReason);
    }
    return map;
  }

  InboxCompanion toCompanion(bool nullToAbsent) {
    return InboxCompanion(
      txId: Value(txId),
      jws: Value(jws),
      amountCents: Value(amountCents),
      senderKid: Value(senderKid),
      receivedAt: Value(receivedAt),
      status: Value(status),
      rejectReason: rejectReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectReason),
    );
  }

  factory InboxRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxRow(
      txId: serializer.fromJson<String>(json['txId']),
      jws: serializer.fromJson<String>(json['jws']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      senderKid: serializer.fromJson<String>(json['senderKid']),
      receivedAt: serializer.fromJson<int>(json['receivedAt']),
      status: $InboxTable.$converterstatus
          .fromJson(serializer.fromJson<int>(json['status'])),
      rejectReason: serializer.fromJson<String?>(json['rejectReason']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'txId': serializer.toJson<String>(txId),
      'jws': serializer.toJson<String>(jws),
      'amountCents': serializer.toJson<int>(amountCents),
      'senderKid': serializer.toJson<String>(senderKid),
      'receivedAt': serializer.toJson<int>(receivedAt),
      'status':
          serializer.toJson<int>($InboxTable.$converterstatus.toJson(status)),
      'rejectReason': serializer.toJson<String?>(rejectReason),
    };
  }

  InboxRow copyWith(
          {String? txId,
          String? jws,
          int? amountCents,
          String? senderKid,
          int? receivedAt,
          TxStatus? status,
          Value<String?> rejectReason = const Value.absent()}) =>
      InboxRow(
        txId: txId ?? this.txId,
        jws: jws ?? this.jws,
        amountCents: amountCents ?? this.amountCents,
        senderKid: senderKid ?? this.senderKid,
        receivedAt: receivedAt ?? this.receivedAt,
        status: status ?? this.status,
        rejectReason:
            rejectReason.present ? rejectReason.value : this.rejectReason,
      );
  InboxRow copyWithCompanion(InboxCompanion data) {
    return InboxRow(
      txId: data.txId.present ? data.txId.value : this.txId,
      jws: data.jws.present ? data.jws.value : this.jws,
      amountCents:
          data.amountCents.present ? data.amountCents.value : this.amountCents,
      senderKid: data.senderKid.present ? data.senderKid.value : this.senderKid,
      receivedAt:
          data.receivedAt.present ? data.receivedAt.value : this.receivedAt,
      status: data.status.present ? data.status.value : this.status,
      rejectReason: data.rejectReason.present
          ? data.rejectReason.value
          : this.rejectReason,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxRow(')
          ..write('txId: $txId, ')
          ..write('jws: $jws, ')
          ..write('amountCents: $amountCents, ')
          ..write('senderKid: $senderKid, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('status: $status, ')
          ..write('rejectReason: $rejectReason')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      txId, jws, amountCents, senderKid, receivedAt, status, rejectReason);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxRow &&
          other.txId == this.txId &&
          other.jws == this.jws &&
          other.amountCents == this.amountCents &&
          other.senderKid == this.senderKid &&
          other.receivedAt == this.receivedAt &&
          other.status == this.status &&
          other.rejectReason == this.rejectReason);
}

class InboxCompanion extends UpdateCompanion<InboxRow> {
  final Value<String> txId;
  final Value<String> jws;
  final Value<int> amountCents;
  final Value<String> senderKid;
  final Value<int> receivedAt;
  final Value<TxStatus> status;
  final Value<String?> rejectReason;
  final Value<int> rowid;
  const InboxCompanion({
    this.txId = const Value.absent(),
    this.jws = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.senderKid = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rejectReason = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxCompanion.insert({
    required String txId,
    required String jws,
    required int amountCents,
    required String senderKid,
    required int receivedAt,
    required TxStatus status,
    this.rejectReason = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : txId = Value(txId),
        jws = Value(jws),
        amountCents = Value(amountCents),
        senderKid = Value(senderKid),
        receivedAt = Value(receivedAt),
        status = Value(status);
  static Insertable<InboxRow> custom({
    Expression<String>? txId,
    Expression<String>? jws,
    Expression<int>? amountCents,
    Expression<String>? senderKid,
    Expression<int>? receivedAt,
    Expression<int>? status,
    Expression<String>? rejectReason,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (txId != null) 'tx_id': txId,
      if (jws != null) 'jws': jws,
      if (amountCents != null) 'amount_cents': amountCents,
      if (senderKid != null) 'sender_kid': senderKid,
      if (receivedAt != null) 'received_at': receivedAt,
      if (status != null) 'status': status,
      if (rejectReason != null) 'reject_reason': rejectReason,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxCompanion copyWith(
      {Value<String>? txId,
      Value<String>? jws,
      Value<int>? amountCents,
      Value<String>? senderKid,
      Value<int>? receivedAt,
      Value<TxStatus>? status,
      Value<String?>? rejectReason,
      Value<int>? rowid}) {
    return InboxCompanion(
      txId: txId ?? this.txId,
      jws: jws ?? this.jws,
      amountCents: amountCents ?? this.amountCents,
      senderKid: senderKid ?? this.senderKid,
      receivedAt: receivedAt ?? this.receivedAt,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (txId.present) {
      map['tx_id'] = Variable<String>(txId.value);
    }
    if (jws.present) {
      map['jws'] = Variable<String>(jws.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (senderKid.present) {
      map['sender_kid'] = Variable<String>(senderKid.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<int>(receivedAt.value);
    }
    if (status.present) {
      map['status'] =
          Variable<int>($InboxTable.$converterstatus.toSql(status.value));
    }
    if (rejectReason.present) {
      map['reject_reason'] = Variable<String>(rejectReason.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxCompanion(')
          ..write('txId: $txId, ')
          ..write('jws: $jws, ')
          ..write('amountCents: $amountCents, ')
          ..write('senderKid: $senderKid, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('status: $status, ')
          ..write('rejectReason: $rejectReason, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BalanceCacheTable extends BalanceCache
    with TableInfo<$BalanceCacheTable, BalanceCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BalanceCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _balanceCentsMeta =
      const VerificationMeta('balanceCents');
  @override
  late final GeneratedColumn<int> balanceCents = GeneratedColumn<int>(
      'balance_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _safeOfflineCentsMeta =
      const VerificationMeta('safeOfflineCents');
  @override
  late final GeneratedColumn<int> safeOfflineCents = GeneratedColumn<int>(
      'safe_offline_cents', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<int> syncedAt = GeneratedColumn<int>(
      'synced_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _policyVersionMeta =
      const VerificationMeta('policyVersion');
  @override
  late final GeneratedColumn<String> policyVersion = GeneratedColumn<String>(
      'policy_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [userId, balanceCents, safeOfflineCents, syncedAt, policyVersion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'balance_cache';
  @override
  VerificationContext validateIntegrity(Insertable<BalanceCacheRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('balance_cents')) {
      context.handle(
          _balanceCentsMeta,
          balanceCents.isAcceptableOrUnknown(
              data['balance_cents']!, _balanceCentsMeta));
    } else if (isInserting) {
      context.missing(_balanceCentsMeta);
    }
    if (data.containsKey('safe_offline_cents')) {
      context.handle(
          _safeOfflineCentsMeta,
          safeOfflineCents.isAcceptableOrUnknown(
              data['safe_offline_cents']!, _safeOfflineCentsMeta));
    } else if (isInserting) {
      context.missing(_safeOfflineCentsMeta);
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    } else if (isInserting) {
      context.missing(_syncedAtMeta);
    }
    if (data.containsKey('policy_version')) {
      context.handle(
          _policyVersionMeta,
          policyVersion.isAcceptableOrUnknown(
              data['policy_version']!, _policyVersionMeta));
    } else if (isInserting) {
      context.missing(_policyVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {userId};
  @override
  BalanceCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BalanceCacheRow(
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      balanceCents: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}balance_cents'])!,
      safeOfflineCents: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}safe_offline_cents'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}synced_at'])!,
      policyVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}policy_version'])!,
    );
  }

  @override
  $BalanceCacheTable createAlias(String alias) {
    return $BalanceCacheTable(attachedDatabase, alias);
  }
}

class BalanceCacheRow extends DataClass implements Insertable<BalanceCacheRow> {
  final String userId;
  final int balanceCents;
  final int safeOfflineCents;
  final int syncedAt;
  final String policyVersion;
  const BalanceCacheRow(
      {required this.userId,
      required this.balanceCents,
      required this.safeOfflineCents,
      required this.syncedAt,
      required this.policyVersion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['user_id'] = Variable<String>(userId);
    map['balance_cents'] = Variable<int>(balanceCents);
    map['safe_offline_cents'] = Variable<int>(safeOfflineCents);
    map['synced_at'] = Variable<int>(syncedAt);
    map['policy_version'] = Variable<String>(policyVersion);
    return map;
  }

  BalanceCacheCompanion toCompanion(bool nullToAbsent) {
    return BalanceCacheCompanion(
      userId: Value(userId),
      balanceCents: Value(balanceCents),
      safeOfflineCents: Value(safeOfflineCents),
      syncedAt: Value(syncedAt),
      policyVersion: Value(policyVersion),
    );
  }

  factory BalanceCacheRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BalanceCacheRow(
      userId: serializer.fromJson<String>(json['userId']),
      balanceCents: serializer.fromJson<int>(json['balanceCents']),
      safeOfflineCents: serializer.fromJson<int>(json['safeOfflineCents']),
      syncedAt: serializer.fromJson<int>(json['syncedAt']),
      policyVersion: serializer.fromJson<String>(json['policyVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'userId': serializer.toJson<String>(userId),
      'balanceCents': serializer.toJson<int>(balanceCents),
      'safeOfflineCents': serializer.toJson<int>(safeOfflineCents),
      'syncedAt': serializer.toJson<int>(syncedAt),
      'policyVersion': serializer.toJson<String>(policyVersion),
    };
  }

  BalanceCacheRow copyWith(
          {String? userId,
          int? balanceCents,
          int? safeOfflineCents,
          int? syncedAt,
          String? policyVersion}) =>
      BalanceCacheRow(
        userId: userId ?? this.userId,
        balanceCents: balanceCents ?? this.balanceCents,
        safeOfflineCents: safeOfflineCents ?? this.safeOfflineCents,
        syncedAt: syncedAt ?? this.syncedAt,
        policyVersion: policyVersion ?? this.policyVersion,
      );
  BalanceCacheRow copyWithCompanion(BalanceCacheCompanion data) {
    return BalanceCacheRow(
      userId: data.userId.present ? data.userId.value : this.userId,
      balanceCents: data.balanceCents.present
          ? data.balanceCents.value
          : this.balanceCents,
      safeOfflineCents: data.safeOfflineCents.present
          ? data.safeOfflineCents.value
          : this.safeOfflineCents,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      policyVersion: data.policyVersion.present
          ? data.policyVersion.value
          : this.policyVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BalanceCacheRow(')
          ..write('userId: $userId, ')
          ..write('balanceCents: $balanceCents, ')
          ..write('safeOfflineCents: $safeOfflineCents, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('policyVersion: $policyVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      userId, balanceCents, safeOfflineCents, syncedAt, policyVersion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BalanceCacheRow &&
          other.userId == this.userId &&
          other.balanceCents == this.balanceCents &&
          other.safeOfflineCents == this.safeOfflineCents &&
          other.syncedAt == this.syncedAt &&
          other.policyVersion == this.policyVersion);
}

class BalanceCacheCompanion extends UpdateCompanion<BalanceCacheRow> {
  final Value<String> userId;
  final Value<int> balanceCents;
  final Value<int> safeOfflineCents;
  final Value<int> syncedAt;
  final Value<String> policyVersion;
  final Value<int> rowid;
  const BalanceCacheCompanion({
    this.userId = const Value.absent(),
    this.balanceCents = const Value.absent(),
    this.safeOfflineCents = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.policyVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BalanceCacheCompanion.insert({
    required String userId,
    required int balanceCents,
    required int safeOfflineCents,
    required int syncedAt,
    required String policyVersion,
    this.rowid = const Value.absent(),
  })  : userId = Value(userId),
        balanceCents = Value(balanceCents),
        safeOfflineCents = Value(safeOfflineCents),
        syncedAt = Value(syncedAt),
        policyVersion = Value(policyVersion);
  static Insertable<BalanceCacheRow> custom({
    Expression<String>? userId,
    Expression<int>? balanceCents,
    Expression<int>? safeOfflineCents,
    Expression<int>? syncedAt,
    Expression<String>? policyVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (userId != null) 'user_id': userId,
      if (balanceCents != null) 'balance_cents': balanceCents,
      if (safeOfflineCents != null) 'safe_offline_cents': safeOfflineCents,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (policyVersion != null) 'policy_version': policyVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BalanceCacheCompanion copyWith(
      {Value<String>? userId,
      Value<int>? balanceCents,
      Value<int>? safeOfflineCents,
      Value<int>? syncedAt,
      Value<String>? policyVersion,
      Value<int>? rowid}) {
    return BalanceCacheCompanion(
      userId: userId ?? this.userId,
      balanceCents: balanceCents ?? this.balanceCents,
      safeOfflineCents: safeOfflineCents ?? this.safeOfflineCents,
      syncedAt: syncedAt ?? this.syncedAt,
      policyVersion: policyVersion ?? this.policyVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (balanceCents.present) {
      map['balance_cents'] = Variable<int>(balanceCents.value);
    }
    if (safeOfflineCents.present) {
      map['safe_offline_cents'] = Variable<int>(safeOfflineCents.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<int>(syncedAt.value);
    }
    if (policyVersion.present) {
      map['policy_version'] = Variable<String>(policyVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BalanceCacheCompanion(')
          ..write('userId: $userId, ')
          ..write('balanceCents: $balanceCents, ')
          ..write('safeOfflineCents: $safeOfflineCents, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $InboxTable inbox = $InboxTable(this);
  late final $BalanceCacheTable balanceCache = $BalanceCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [outbox, inbox, balanceCache];
}

typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String txId,
  required String jws,
  required int amountCents,
  required String receiverKid,
  required int createdAt,
  required TxStatus status,
  Value<String?> rejectReason,
  Value<String?> ackSig,
  Value<int> attemptCount,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> txId,
  Value<String> jws,
  Value<int> amountCents,
  Value<String> receiverKid,
  Value<int> createdAt,
  Value<TxStatus> status,
  Value<String?> rejectReason,
  Value<String?> ackSig,
  Value<int> attemptCount,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer extends Composer<_$AppDb, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get txId => $composableBuilder(
      column: $table.txId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jws => $composableBuilder(
      column: $table.jws, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiverKid => $composableBuilder(
      column: $table.receiverKid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TxStatus, TxStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ackSig => $composableBuilder(
      column: $table.ackSig, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer extends Composer<_$AppDb, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get txId => $composableBuilder(
      column: $table.txId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jws => $composableBuilder(
      column: $table.jws, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiverKid => $composableBuilder(
      column: $table.receiverKid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ackSig => $composableBuilder(
      column: $table.ackSig, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount,
      builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer extends Composer<_$AppDb, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get txId =>
      $composableBuilder(column: $table.txId, builder: (column) => column);

  GeneratedColumn<String> get jws =>
      $composableBuilder(column: $table.jws, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<String> get receiverKid => $composableBuilder(
      column: $table.receiverKid, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason, builder: (column) => column);

  GeneratedColumn<String> get ackSig =>
      $composableBuilder(column: $table.ackSig, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
      column: $table.attemptCount, builder: (column) => column);
}

class $$OutboxTableTableManager extends RootTableManager<
    _$AppDb,
    $OutboxTable,
    OutboxRow,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxRow, BaseReferences<_$AppDb, $OutboxTable, OutboxRow>),
    OutboxRow,
    PrefetchHooks Function()> {
  $$OutboxTableTableManager(_$AppDb db, $OutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> txId = const Value.absent(),
            Value<String> jws = const Value.absent(),
            Value<int> amountCents = const Value.absent(),
            Value<String> receiverKid = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<TxStatus> status = const Value.absent(),
            Value<String?> rejectReason = const Value.absent(),
            Value<String?> ackSig = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion(
            txId: txId,
            jws: jws,
            amountCents: amountCents,
            receiverKid: receiverKid,
            createdAt: createdAt,
            status: status,
            rejectReason: rejectReason,
            ackSig: ackSig,
            attemptCount: attemptCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String txId,
            required String jws,
            required int amountCents,
            required String receiverKid,
            required int createdAt,
            required TxStatus status,
            Value<String?> rejectReason = const Value.absent(),
            Value<String?> ackSig = const Value.absent(),
            Value<int> attemptCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutboxCompanion.insert(
            txId: txId,
            jws: jws,
            amountCents: amountCents,
            receiverKid: receiverKid,
            createdAt: createdAt,
            status: status,
            rejectReason: rejectReason,
            ackSig: ackSig,
            attemptCount: attemptCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $OutboxTable,
    OutboxRow,
    $$OutboxTableFilterComposer,
    $$OutboxTableOrderingComposer,
    $$OutboxTableAnnotationComposer,
    $$OutboxTableCreateCompanionBuilder,
    $$OutboxTableUpdateCompanionBuilder,
    (OutboxRow, BaseReferences<_$AppDb, $OutboxTable, OutboxRow>),
    OutboxRow,
    PrefetchHooks Function()>;
typedef $$InboxTableCreateCompanionBuilder = InboxCompanion Function({
  required String txId,
  required String jws,
  required int amountCents,
  required String senderKid,
  required int receivedAt,
  required TxStatus status,
  Value<String?> rejectReason,
  Value<int> rowid,
});
typedef $$InboxTableUpdateCompanionBuilder = InboxCompanion Function({
  Value<String> txId,
  Value<String> jws,
  Value<int> amountCents,
  Value<String> senderKid,
  Value<int> receivedAt,
  Value<TxStatus> status,
  Value<String?> rejectReason,
  Value<int> rowid,
});

class $$InboxTableFilterComposer extends Composer<_$AppDb, $InboxTable> {
  $$InboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get txId => $composableBuilder(
      column: $table.txId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jws => $composableBuilder(
      column: $table.jws, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderKid => $composableBuilder(
      column: $table.senderKid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TxStatus, TxStatus, int> get status =>
      $composableBuilder(
          column: $table.status,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason, builder: (column) => ColumnFilters(column));
}

class $$InboxTableOrderingComposer extends Composer<_$AppDb, $InboxTable> {
  $$InboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get txId => $composableBuilder(
      column: $table.txId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jws => $composableBuilder(
      column: $table.jws, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderKid => $composableBuilder(
      column: $table.senderKid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason,
      builder: (column) => ColumnOrderings(column));
}

class $$InboxTableAnnotationComposer extends Composer<_$AppDb, $InboxTable> {
  $$InboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get txId =>
      $composableBuilder(column: $table.txId, builder: (column) => column);

  GeneratedColumn<String> get jws =>
      $composableBuilder(column: $table.jws, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
      column: $table.amountCents, builder: (column) => column);

  GeneratedColumn<String> get senderKid =>
      $composableBuilder(column: $table.senderKid, builder: (column) => column);

  GeneratedColumn<int> get receivedAt => $composableBuilder(
      column: $table.receivedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxStatus, int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rejectReason => $composableBuilder(
      column: $table.rejectReason, builder: (column) => column);
}

class $$InboxTableTableManager extends RootTableManager<
    _$AppDb,
    $InboxTable,
    InboxRow,
    $$InboxTableFilterComposer,
    $$InboxTableOrderingComposer,
    $$InboxTableAnnotationComposer,
    $$InboxTableCreateCompanionBuilder,
    $$InboxTableUpdateCompanionBuilder,
    (InboxRow, BaseReferences<_$AppDb, $InboxTable, InboxRow>),
    InboxRow,
    PrefetchHooks Function()> {
  $$InboxTableTableManager(_$AppDb db, $InboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> txId = const Value.absent(),
            Value<String> jws = const Value.absent(),
            Value<int> amountCents = const Value.absent(),
            Value<String> senderKid = const Value.absent(),
            Value<int> receivedAt = const Value.absent(),
            Value<TxStatus> status = const Value.absent(),
            Value<String?> rejectReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxCompanion(
            txId: txId,
            jws: jws,
            amountCents: amountCents,
            senderKid: senderKid,
            receivedAt: receivedAt,
            status: status,
            rejectReason: rejectReason,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String txId,
            required String jws,
            required int amountCents,
            required String senderKid,
            required int receivedAt,
            required TxStatus status,
            Value<String?> rejectReason = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InboxCompanion.insert(
            txId: txId,
            jws: jws,
            amountCents: amountCents,
            senderKid: senderKid,
            receivedAt: receivedAt,
            status: status,
            rejectReason: rejectReason,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $InboxTable,
    InboxRow,
    $$InboxTableFilterComposer,
    $$InboxTableOrderingComposer,
    $$InboxTableAnnotationComposer,
    $$InboxTableCreateCompanionBuilder,
    $$InboxTableUpdateCompanionBuilder,
    (InboxRow, BaseReferences<_$AppDb, $InboxTable, InboxRow>),
    InboxRow,
    PrefetchHooks Function()>;
typedef $$BalanceCacheTableCreateCompanionBuilder = BalanceCacheCompanion
    Function({
  required String userId,
  required int balanceCents,
  required int safeOfflineCents,
  required int syncedAt,
  required String policyVersion,
  Value<int> rowid,
});
typedef $$BalanceCacheTableUpdateCompanionBuilder = BalanceCacheCompanion
    Function({
  Value<String> userId,
  Value<int> balanceCents,
  Value<int> safeOfflineCents,
  Value<int> syncedAt,
  Value<String> policyVersion,
  Value<int> rowid,
});

class $$BalanceCacheTableFilterComposer
    extends Composer<_$AppDb, $BalanceCacheTable> {
  $$BalanceCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get balanceCents => $composableBuilder(
      column: $table.balanceCents, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get safeOfflineCents => $composableBuilder(
      column: $table.safeOfflineCents,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get policyVersion => $composableBuilder(
      column: $table.policyVersion, builder: (column) => ColumnFilters(column));
}

class $$BalanceCacheTableOrderingComposer
    extends Composer<_$AppDb, $BalanceCacheTable> {
  $$BalanceCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get balanceCents => $composableBuilder(
      column: $table.balanceCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get safeOfflineCents => $composableBuilder(
      column: $table.safeOfflineCents,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get policyVersion => $composableBuilder(
      column: $table.policyVersion,
      builder: (column) => ColumnOrderings(column));
}

class $$BalanceCacheTableAnnotationComposer
    extends Composer<_$AppDb, $BalanceCacheTable> {
  $$BalanceCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<int> get balanceCents => $composableBuilder(
      column: $table.balanceCents, builder: (column) => column);

  GeneratedColumn<int> get safeOfflineCents => $composableBuilder(
      column: $table.safeOfflineCents, builder: (column) => column);

  GeneratedColumn<int> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get policyVersion => $composableBuilder(
      column: $table.policyVersion, builder: (column) => column);
}

class $$BalanceCacheTableTableManager extends RootTableManager<
    _$AppDb,
    $BalanceCacheTable,
    BalanceCacheRow,
    $$BalanceCacheTableFilterComposer,
    $$BalanceCacheTableOrderingComposer,
    $$BalanceCacheTableAnnotationComposer,
    $$BalanceCacheTableCreateCompanionBuilder,
    $$BalanceCacheTableUpdateCompanionBuilder,
    (
      BalanceCacheRow,
      BaseReferences<_$AppDb, $BalanceCacheTable, BalanceCacheRow>
    ),
    BalanceCacheRow,
    PrefetchHooks Function()> {
  $$BalanceCacheTableTableManager(_$AppDb db, $BalanceCacheTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BalanceCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BalanceCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BalanceCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> userId = const Value.absent(),
            Value<int> balanceCents = const Value.absent(),
            Value<int> safeOfflineCents = const Value.absent(),
            Value<int> syncedAt = const Value.absent(),
            Value<String> policyVersion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BalanceCacheCompanion(
            userId: userId,
            balanceCents: balanceCents,
            safeOfflineCents: safeOfflineCents,
            syncedAt: syncedAt,
            policyVersion: policyVersion,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String userId,
            required int balanceCents,
            required int safeOfflineCents,
            required int syncedAt,
            required String policyVersion,
            Value<int> rowid = const Value.absent(),
          }) =>
              BalanceCacheCompanion.insert(
            userId: userId,
            balanceCents: balanceCents,
            safeOfflineCents: safeOfflineCents,
            syncedAt: syncedAt,
            policyVersion: policyVersion,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BalanceCacheTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $BalanceCacheTable,
    BalanceCacheRow,
    $$BalanceCacheTableFilterComposer,
    $$BalanceCacheTableOrderingComposer,
    $$BalanceCacheTableAnnotationComposer,
    $$BalanceCacheTableCreateCompanionBuilder,
    $$BalanceCacheTableUpdateCompanionBuilder,
    (
      BalanceCacheRow,
      BaseReferences<_$AppDb, $BalanceCacheTable, BalanceCacheRow>
    ),
    BalanceCacheRow,
    PrefetchHooks Function()>;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$InboxTableTableManager get inbox =>
      $$InboxTableTableManager(_db, _db.inbox);
  $$BalanceCacheTableTableManager get balanceCache =>
      $$BalanceCacheTableTableManager(_db, _db.balanceCache);
}
