import 'package:flutter_test/flutter_test.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_policy.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_service.dart';
import 'package:tng_clone_flutter/core/connectivity/connectivity_state.dart';

void main() {
  group('ConnectivityPolicy', () {
    test('keeps online state within cache confidence window', () {
      const policy = ConnectivityPolicy();
      final now = DateTime(2026, 4, 25, 12, 0, 0);
      final tier = policy.evaluateTier(
        hasNetwork: true,
        lastSyncedAt: now.subtract(const Duration(minutes: 4)),
        consecutiveSyncFailures: 0,
        now: now,
      );

      expect(tier, ConnectivityTier.online);
    });

    test('drops to offline as soon as network is unavailable', () {
      const policy = ConnectivityPolicy();
      final now = DateTime(2026, 4, 25, 12, 0, 0);
      final tier = policy.evaluateTier(
        hasNetwork: false,
        lastSyncedAt: now.subtract(const Duration(minutes: 2)),
        consecutiveSyncFailures: 0,
        now: now,
      );

      expect(tier, ConnectivityTier.offline);
    });

    test('keeps stale state when sync fails repeatedly with fresh cache', () {
      const policy = ConnectivityPolicy();
      final now = DateTime(2026, 4, 25, 12, 0, 0);
      final tier = policy.evaluateTier(
        hasNetwork: true,
        lastSyncedAt: now.subtract(const Duration(minutes: 2)),
        consecutiveSyncFailures: 3,
        now: now,
      );

      expect(tier, ConnectivityTier.stale);
    });

    test('drops to offline after cache confidence expires', () {
      const policy = ConnectivityPolicy();
      final now = DateTime(2026, 4, 25, 12, 0, 0);
      final tier = policy.evaluateTier(
        hasNetwork: true,
        lastSyncedAt: now.subtract(const Duration(minutes: 11)),
        consecutiveSyncFailures: 0,
        now: now,
      );

      expect(tier, ConnectivityTier.offline);
    });
  });

  group('ConnectivityService', () {
    test('updates state when network and sync conditions change', () {
      var now = DateTime(2026, 4, 25, 12, 0, 0);
      final service = ConnectivityService(
        now: () => now,
        heartbeat: const Duration(days: 1),
      );

      addTearDown(service.dispose);

      expect(service.state.tier, ConnectivityTier.online);

      service.setNetworkAvailable(false);
      expect(service.state.hasNetwork, isFalse);
      expect(service.state.tier, ConnectivityTier.offline);

      service.ageLastSyncBy(const Duration(minutes: 11));
      expect(service.state.tier, ConnectivityTier.offline);

      now = now.add(const Duration(minutes: 1));
      service.setNetworkAvailable(true);
      service.markSyncSuccess();
      expect(service.state.tier, ConnectivityTier.online);
      expect(service.state.bannerText(now), contains('Online'));
    });
  });
}
