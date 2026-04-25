import 'package:dio/dio.dart';

class DevicesApi {
  final Dio _dio;
  DevicesApi(this._dio);

  Future<Map<String, dynamic>> register({
    required String userId,
    required String deviceLabel,
    required String publicKey,
    required List<String> attestationChain,
    required String alg,
    required String androidIdHash,
  }) async {
    final response = await _dio.post('/devices/register', data: {
      'user_id': userId,
      'device_label': deviceLabel,
      'public_key': publicKey,
      'attestation_chain': attestationChain,
      'alg': alg,
      'android_id_hash': androidIdHash,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> attest({
    required String publicKey,
    required List<String> attestationChain,
  }) async {
    final response = await _dio.post('/devices/attest', data: {
      'public_key': publicKey,
      'attestation_chain': attestationChain,
    });
    return response.data;
  }
}
