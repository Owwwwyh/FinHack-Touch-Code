import 'package:dio/dio.dart';

class TokensApi {
  final Dio _dio;
  TokensApi(this._dio);

  Future<Map<String, dynamic>> settle({
    required String deviceId,
    required String batchId,
    required List<String> tokens,
  }) async {
    final response = await _dio.post('/tokens/settle', data: {
      'device_id': deviceId,
      'batch_id': batchId,
      'tokens': tokens,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> dispute({
    required String txId,
    required String reasonCode,
    String? details,
  }) async {
    final response = await _dio.post('/tokens/dispute', data: {
      'tx_id': txId,
      'reason_code': reasonCode,
      if (details != null) 'details': details,
    });
    return response.data;
  }
}
