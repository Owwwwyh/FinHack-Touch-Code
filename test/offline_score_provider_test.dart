import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_provider.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_service.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_state.dart';
import 'package:tng_clone_flutter/domain/services/credit_scorer.dart';
import 'package:tng_clone_flutter/features/home/offline/offline_score_provider.dart';

void main() {
  group('baseOfflineScoreProvider', () {
    test('score decays as sync age increases via ConnectivityService', () {
      var now = DateTime(2026, 4, 25, 12, 0, 0);

      // The container owns the ConnectivityService — do not add a separate tearDown.
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWith(
            (_) => ConnectivityService(
              now: () => now,
              heartbeat: const Duration(days: 99),
            ),
          ),
          scoringClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final fresh = container.read(baseOfflineScoreProvider);
      expect(fresh.isAiEligible, isTrue);
      expect(fresh.lastSyncAgeMinutes, 0);

      // Age the last sync 30 minutes into the past (scoring clock stays at `now`).
      container
          .read(connectivityServiceProvider.notifier)
          .ageLastSyncBy(const Duration(minutes: 30));

      final stale = container.read(baseOfflineScoreProvider);
      expect(stale.lastSyncAgeMinutes, 30);
      expect(
        stale.safeOfflineBalanceCents,
        lessThan(fresh.safeOfflineBalanceCents),
      );
    });

    test('going offline triggers connectivity tier change', () {
      var now = DateTime(2026, 4, 25, 12, 0, 0);

      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWith(
            (_) => ConnectivityService(
              now: () => now,
              heartbeat: const Duration(days: 99),
            ),
          ),
          scoringClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      final online = container.read(connectivityServiceProvider);
      expect(online.tier, ConnectivityTier.online);

      container
          .read(connectivityServiceProvider.notifier)
          .setNetworkAvailable(false);

      final offline = container.read(connectivityServiceProvider);
      expect(offline.tier, ConnectivityTier.offline);
      expect(offline.hasNetwork, isFalse);
    });

    test('available balance deducts pending outgoing', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile.day2Demo();

      final decision = scorer.score(profile: profile, lastSyncAgeMinutes: 0);

      final full = decision.availableSafeBalanceCents(pendingOutgoingCents: 0);
      final reduced =
          decision.availableSafeBalanceCents(pendingOutgoingCents: 2000);
      final zeroed = decision.availableSafeBalanceCents(
        pendingOutgoingCents: decision.safeOfflineBalanceCents + 1,
      );

      expect(reduced, equals(full - 2000));
      expect(zeroed, equals(0));
    });

    test('panelDrivers appends pending settlement entry when pending > 0', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile.day2Demo();

      final decision = scorer.score(profile: profile, lastSyncAgeMinutes: 0);

      final driversNoPending = decision.panelDrivers(pendingOutgoingCents: 0);
      final driversPending = decision.panelDrivers(pendingOutgoingCents: 500);

      expect(driversNoPending.length, equals(decision.drivers.length));
      expect(driversPending.length, equals(decision.drivers.length + 1));
      expect(driversPending.last.label, equals('Pending settlement'));
      expect(driversPending.last.isPositive, isFalse);
    });

    test('users below 600 tx are not AI eligible', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile(
        cachedBalanceCents: 10000,
        lifetimeTransactionCount: 599,
        manualOfflineWalletCents: 3000,
        policyVersion: 'v3.2026-04-22',
        modelVersion: 'credit-v1-demo',
        features: CreditModelFeatures(
          txCount30d: 10,
          txCount90d: 30,
          avgTxAmount30d: 8,
          medianTxAmount30d: 7,
          txAmountP95_30d: 20,
          uniquePayees30d: 4,
          uniquePayees90d: 8,
          payeeDiversityIndex: 1.0,
          reloadFreq30d: 2,
          reloadAmountAvg: 30,
          daysSinceLastReload: 1,
          timeOfDayPrimary: 10,
          weekdayShare: 0.7,
          geoDispersionKm: 2.0,
          priorOfflineCount: 3,
          priorOfflineSettleRate: 1,
          accountAgeDays: 120,
          kycTier: 1,
          deviceAttestOk: 1,
        ),
      );

      final decision = scorer.score(profile: profile, lastSyncAgeMinutes: 0);

      expect(decision.isAiEligible, isFalse);
      expect(decision.safeOfflineBalanceCents, 3000);
      expect(decision.confidence, 0.0);
    });

    test('hard cap clamps AI score to KYC tier 0 limit (RM 20)', () {
      const scorer = CreditScorer();
      final profile = OfflineWalletProfile(
        cachedBalanceCents: 100000,
        lifetimeTransactionCount: 700,
        manualOfflineWalletCents: 5000,
        policyVersion: 'v3.2026-04-22',
        modelVersion: 'credit-v1-demo',
        features: CreditModelFeatures(
          txCount30d: 100,
          txCount90d: 300,
          avgTxAmount30d: 50,
          medianTxAmount30d: 40,
          txAmountP95_30d: 100,
          uniquePayees30d: 30,
          uniquePayees90d: 60,
          payeeDiversityIndex: 2.0,
          reloadFreq30d: 5,
          reloadAmountAvg: 200,
          daysSinceLastReload: 1,
          timeOfDayPrimary: 12,
          weekdayShare: 0.8,
          geoDispersionKm: 1.0,
          priorOfflineCount: 50,
          priorOfflineSettleRate: 1.0,
          accountAgeDays: 1000,
          kycTier: 0,
          deviceAttestOk: 1,
        ),
      );

      final decision = scorer.score(profile: profile, lastSyncAgeMinutes: 0);

      expect(decision.hardCapCents, 2000);
      expect(decision.safeOfflineBalanceCents, lessThanOrEqualTo(2000));
    });
  });
}
