import '../../data/api/tokens_api.dart';
import '../../data/db/outbox_dao.dart';

class SettlePending {
  final TokensApi tokensApi;
  final OutboxDao outboxDao;

  SettlePending({required this.tokensApi, required this.outboxDao});

  Future<void> call({String? deviceId, int limit = 50}) async {
    final pending = await outboxDao.getPending(limit: limit);
    if (pending.isEmpty) return;

    final batchId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final jwsList = pending.map((r) => r.jws).toList();

    try {
      final result = await tokensApi.settle(
        deviceId: deviceId ?? '',
        batchId: batchId,
        tokens: jwsList,
      );

      final results = result['results'] as List<dynamic>;
      await outboxDao.applyResults(
        results.map((r) => r as Map<String, dynamic>).toList(),
      );
    } catch (e) {
      // Settlement will be retried on next connectivity
      rethrow;
    }
  }
}
