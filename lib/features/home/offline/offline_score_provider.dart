import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connectivity_provider.dart';
import '../../../domain/services/credit_scorer.dart';

final creditScorerProvider = Provider<CreditScorer>((ref) {
  return const CreditScorer();
});

final offlineWalletProfileProvider = Provider<OfflineWalletProfile>((ref) {
  return OfflineWalletProfile.day2Demo();
});

final baseOfflineScoreProvider = Provider<CreditScoreDecision>((ref) {
  final scorer = ref.watch(creditScorerProvider);
  final profile = ref.watch(offlineWalletProfileProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final lastSyncedAt = connectivity.lastSyncedAt;
  final now = DateTime.now();
  final lastSyncAgeMinutes = lastSyncedAt == null
      ? 0
      : now.difference(lastSyncedAt).inMinutes.clamp(0, 72 * 60);

  return scorer.score(
    profile: profile,
    lastSyncAgeMinutes: lastSyncAgeMinutes,
  );
});
