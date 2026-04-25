import 'connectivity_state.dart';

class ConnectivityPolicy {
  const ConnectivityPolicy({
    this.cacheConfidenceWindow = const Duration(minutes: 10),
  });

  final Duration cacheConfidenceWindow;

  ConnectivityTier evaluateTier({
    required bool hasNetwork,
    required DateTime? lastSyncedAt,
    required int consecutiveSyncFailures,
    required DateTime now,
  }) {
    if (lastSyncedAt == null) {
      return hasNetwork ? ConnectivityTier.stale : ConnectivityTier.offline;
    }

    final age = now.difference(lastSyncedAt);
    final normalizedAge = age.isNegative ? Duration.zero : age;

    if (normalizedAge > cacheConfidenceWindow) {
      return ConnectivityTier.offline;
    }

    if (!hasNetwork || consecutiveSyncFailures >= 3) {
      return ConnectivityTier.stale;
    }

    return ConnectivityTier.online;
  }
}
