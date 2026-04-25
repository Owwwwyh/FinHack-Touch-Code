import 'package:dio/dio.dart';

class ScoreApi {
  final Dio _dio;
  ScoreApi(this._dio);

  Future<Map<String, dynamic>> refresh({
    required String userId,
    required String policyVersion,
    required Map<String, dynamic> features,
  }) async {
    final response = await _dio.post('/score/refresh', data: {
      'user_id': userId,
      'policy_version': policyVersion,
      'features': features,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getPolicy() async {
    final response = await _dio.get('/score/policy');
    return response.data;
  }

  Future<Map<String, dynamic>> getPublicKey(String kid) async {
    final response = await _dio.get('/publickeys/$kid');
    return response.data;
  }
}
