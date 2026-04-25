import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

part 'wallet_api.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class WalletBalanceResponse {
  final String userId;
  final String balanceMyr;
  final String currency;
  final int version;
  final DateTime asOf;
  final String safeOfflineBalanceMyr;
  final String policyVersion;

  WalletBalanceResponse({
    required this.userId,
    required this.balanceMyr,
    required this.currency,
    required this.version,
    required this.asOf,
    required this.safeOfflineBalanceMyr,
    required this.policyVersion,
  });

  factory WalletBalanceResponse.fromJson(Map<String, dynamic> json) =>
      _$WalletBalanceResponseFromJson(json);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class WalletSyncRequest {
  final String userId;
  final int sinceVersion;

  WalletSyncRequest({required this.userId, required this.sinceVersion});

  Map<String, dynamic> toJson() => _$WalletSyncRequestToJson(this);
}

class WalletApi {
  final Dio _dio;
  WalletApi(this._dio);

  Future<WalletBalanceResponse> getBalance() async {
    final response = await _dio.get('/wallet/balance');
    return WalletBalanceResponse.fromJson(response.data);
  }

  Future<WalletBalanceResponse> sync(WalletSyncRequest request) async {
    final response = await _dio.post('/wallet/sync', data: request.toJson());
    return WalletBalanceResponse.fromJson(response.data);
  }
}
