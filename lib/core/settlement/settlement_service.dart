import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/offline_transfer.dart';

const _baseUrl = 'http://10.0.2.2:3000/v1';
const _demoAuthToken = 'demo-token';
const _maxBatchSize = 50;

class RejectedToken {
  const RejectedToken({required this.txId, required this.reason});
  final String txId;
  final String reason;
}

class SettlementResult {
  const SettlementResult({required this.settledIds, required this.rejected});
  final List<String> settledIds;
  final List<RejectedToken> rejected;
}

class SettlementService {
  SettlementService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  Future<SettlementResult> settleBatch(List<OfflineTransfer> tokens) async {
    final batch = tokens
        .where((t) => t.jws != null)
        .take(_maxBatchSize)
        .toList();

    if (batch.isEmpty) {
      return const SettlementResult(settledIds: [], rejected: []);
    }

    final ackSignatures = batch
        .where((t) => t.ackSignature != null)
        .map((t) => {
              'tx_id': t.txId,
              'ack_sig': t.ackSignature!,
              'ack_kid': t.receiverKid,
            })
        .toList();

    final body = jsonEncode({
      'device_id': 'did:tng:device:demo',
      'batch_id': _batchId(),
      'tokens': batch.map((t) => t.jws!).toList(),
      'ack_signatures': ackSignatures,
    });

    final request = await _httpClient
        .postUrl(Uri.parse('$_baseUrl/tokens/settle'))
        .timeout(const Duration(seconds: 10));
    request.headers
      ..set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8')
      ..set(HttpHeaders.authorizationHeader, 'Bearer $_demoAuthToken');
    request.write(body);

    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception(
          'Settlement failed (${response.statusCode}): $responseBody');
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final results = (json['results'] as List<dynamic>?) ?? [];

    final settledIds = <String>[];
    final rejected = <RejectedToken>[];

    for (final item in results.cast<Map<String, dynamic>>()) {
      final txId = item['tx_id'] as String? ?? '';
      final status = item['status'] as String? ?? '';
      if (status == 'SETTLED') {
        settledIds.add(txId);
      } else if (status == 'REJECTED') {
        rejected.add(RejectedToken(
          txId: txId,
          reason: item['reason'] as String? ?? 'UNKNOWN',
        ));
      }
    }

    return SettlementResult(settledIds: settledIds, rejected: rejected);
  }

  String _batchId() {
    final ms = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return '01${ms.padLeft(10, '0')}BAT';
  }
}

final settlementServiceProvider = Provider<SettlementService>((ref) {
  final service = SettlementService();
  ref.onDispose(() => service._httpClient.close());
  return service;
});
