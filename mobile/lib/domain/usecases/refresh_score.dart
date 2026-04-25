import 'dart:math';
import '../../data/api/score_api.dart';
import '../../data/db/balance_cache_dao.dart';
import '../../data/ml/credit_scorer.dart';

class RefreshScore {
  final ScoreApi scoreApi;
  final CreditScorer creditScorer;
  final BalanceCacheDao balanceCacheDao;

  RefreshScore({
    required this.scoreApi,
    required this.creditScorer,
    required this.balanceCacheDao,
  });

  /// Refresh safe offline balance. Tries server first, falls back to on-device.
  Future<int> call({
    required String userId,
    required String policyVersion,
    required Map<String, dynamic> features,
    required int cachedBalanceCents,
    required int hardCapCents,
  }) async {
    int serverSafeCents = -1;

    // Try server refresh (800ms timeout)
    try {
      final response = await scoreApi.refresh(
        userId: userId,
        policyVersion: policyVersion,
        features: features,
      ).timeout(const Duration(milliseconds: 800));

      final safeMyr = double.parse(response['safe_offline_balance_myr'] as String);
      serverSafeCents = (safeMyr * 100).round();
    } catch (_) {
      // Fallback to on-device estimate
    }

    // On-device inference
    final featureList = features.values.map((v) => (v as num).toDouble()).toList();
    final deviceScore = await creditScorer.predict(featureList);
    final deviceSafeCents = deviceScore.round();

    // Use server result if available, otherwise device
    final rawCents = serverSafeCents >= 0 ? serverSafeCents : deviceSafeCents;

    // Clamp: min(raw, cached_balance, hard_cap)
    final safeCents = [rawCents, cachedBalanceCents, hardCapCents].reduce(min);

    // Update cache
    await balanceCacheDao.updateSafeOffline(userId, safeCents);

    return safeCents;
  }
}
