import 'package:json_annotation/json_annotation.dart';

part 'token.g.dart';

/// Domain model for an offline payment token (JWS).
@JsonSerializable(fieldRename: FieldRename.snake)
class OfflineToken {
  final String txId;
  final String senderKid;
  final String senderUserId;
  final String receiverKid;
  final String receiverUserId;
  final String amountValue;
  final String currency;
  final int amountScale;
  final String nonce;
  final int iat;
  final int exp;
  final String policyVersion;
  final String? policySignedBalance;
  final Map<String, dynamic>? geo;

  OfflineToken({
    required this.txId,
    required this.senderKid,
    required this.senderUserId,
    required this.receiverKid,
    required this.receiverUserId,
    required this.amountValue,
    this.currency = 'MYR',
    this.amountScale = 2,
    required this.nonce,
    required this.iat,
    required this.exp,
    required this.policyVersion,
    this.policySignedBalance,
    this.geo,
  });

  factory OfflineToken.fromJson(Map<String, dynamic> json) =>
      _$OfflineTokenFromJson(json);
  Map<String, dynamic> toJson() => _$OfflineTokenToJson(this);

  /// Amount in cents for integer arithmetic.
  int get amountCents => (double.parse(amountValue) * 100).round();
}
