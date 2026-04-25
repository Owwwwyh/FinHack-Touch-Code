enum ConnectivityTier {
  online,
  stale,
  offline,
}

class ConnectivityViewState {
  const ConnectivityViewState({
    required this.tier,
    required this.hasNetwork,
    required this.lastSyncedAt,
    required this.consecutiveSyncFailures,
  });

  final ConnectivityTier tier;
  final bool hasNetwork;
  final DateTime? lastSyncedAt;
  final int consecutiveSyncFailures;

  String bannerText(DateTime now) {
    final minutes = syncAgeMinutes(now);

    switch (tier) {
      case ConnectivityTier.online:
        return 'Online · synced ${minutes ?? 0} min ago';
      case ConnectivityTier.stale:
        return 'Stale · last sync ${minutes ?? '?'} min ago';
      case ConnectivityTier.offline:
        return 'Offline · last sync ${minutes ?? '?'} min ago';
    }
  }

  int? syncAgeMinutes(DateTime now) {
    if (lastSyncedAt == null) {
      return null;
    }

    final age = now.difference(lastSyncedAt!);
    if (age.isNegative) {
      return 0;
    }

    return age.inMinutes;
  }
}
