import 'package:flutter_test/flutter_test.dart';
import 'package:tng_clone_flutter/domain/services/credit_scorer.dart';

void main() {
  group('CreditScorer', () {
    test('matches the Day 2 demo-safe balance at fresh sync', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile.day2Demo();

      final decision = scorer.score(
        profile: profile,
        lastSyncAgeMinutes: 0,
      );

      expect(decision.isAiEligible, isTrue);
      expect(decision.safeOfflineBalanceCents, 12000);
      expect(
        decision.availableSafeBalanceCents(pendingOutgoingCents: 850),
        11150,
      );
    });

    test('decays safe balance as sync age gets older', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile.day2Demo();

      final fresh = scorer.score(
        profile: profile,
        lastSyncAgeMinutes: 0,
      );
      final aged = scorer.score(
        profile: profile,
        lastSyncAgeMinutes: 12,
      );

      expect(aged.safeOfflineBalanceCents,
          lessThan(fresh.safeOfflineBalanceCents));
      expect(aged.lastSyncAgeMinutes, 12);
    });

    test('falls back to manual offline wallet for users below 600 tx', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile(
        cachedBalanceCents: 24850,
        lifetimeTransactionCount: 120,
        manualOfflineWalletCents: 5000,
        policyVersion: 'v3.2026-04-22',
        modelVersion: 'credit-v1-demo',
        features: CreditModelFeatures(
          txCount30d: 18,
          txCount90d: 54,
          avgTxAmount30d: 12,
          medianTxAmount30d: 10,
          txAmountP95_30d: 32,
          uniquePayees30d: 7,
          uniquePayees90d: 13,
          payeeDiversityIndex: 1.1,
          reloadFreq30d: 3,
          reloadAmountAvg: 45,
          daysSinceLastReload: 2,
          timeOfDayPrimary: 12,
          weekdayShare: 0.8,
          geoDispersionKm: 3.2,
          priorOfflineCount: 4,
          priorOfflineSettleRate: 1,
          accountAgeDays: 90,
          kycTier: 1,
          deviceAttestOk: 1,
        ),
      );

      final decision = scorer.score(
        profile: profile,
        lastSyncAgeMinutes: 0,
      );

      expect(decision.isAiEligible, isFalse);
      expect(decision.safeOfflineBalanceCents, 5000);
      expect(decision.drivers.first.label, 'History building');
    });
  });
}
