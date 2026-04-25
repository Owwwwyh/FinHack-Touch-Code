import 'dart:math' as math;

class CreditModelFeatures {
  const CreditModelFeatures({
    required this.txCount30d,
    required this.txCount90d,
    required this.avgTxAmount30d,
    required this.medianTxAmount30d,
    required this.txAmountP95_30d,
    required this.uniquePayees30d,
    required this.uniquePayees90d,
    required this.payeeDiversityIndex,
    required this.reloadFreq30d,
    required this.reloadAmountAvg,
    required this.daysSinceLastReload,
    required this.timeOfDayPrimary,
    required this.weekdayShare,
    required this.geoDispersionKm,
    required this.priorOfflineCount,
    required this.priorOfflineSettleRate,
    required this.accountAgeDays,
    required this.kycTier,
    required this.deviceAttestOk,
  });

  final double txCount30d;
  final double txCount90d;
  final double avgTxAmount30d;
  final double medianTxAmount30d;
  final double txAmountP95_30d;
  final double uniquePayees30d;
  final double uniquePayees90d;
  final double payeeDiversityIndex;
  final double reloadFreq30d;
  final double reloadAmountAvg;
  final double daysSinceLastReload;
  final double timeOfDayPrimary;
  final double weekdayShare;
  final double geoDispersionKm;
  final double priorOfflineCount;
  final double priorOfflineSettleRate;
  final double accountAgeDays;
  final double kycTier;
  final double deviceAttestOk;

  List<double> toVector({required int lastSyncAgeMinutes}) {
    return <double>[
      txCount30d,
      txCount90d,
      avgTxAmount30d,
      medianTxAmount30d,
      txAmountP95_30d,
      uniquePayees30d,
      uniquePayees90d,
      payeeDiversityIndex,
      reloadFreq30d,
      reloadAmountAvg,
      daysSinceLastReload,
      timeOfDayPrimary,
      weekdayShare,
      geoDispersionKm,
      priorOfflineCount,
      priorOfflineSettleRate,
      accountAgeDays,
      kycTier,
      lastSyncAgeMinutes.toDouble(),
      deviceAttestOk,
    ];
  }
}

class OfflineWalletProfile {
  const OfflineWalletProfile({
    required this.cachedBalanceCents,
    required this.lifetimeTransactionCount,
    required this.manualOfflineWalletCents,
    required this.policyVersion,
    required this.modelVersion,
    required this.features,
  });

  factory OfflineWalletProfile.day2Demo() {
    return const OfflineWalletProfile(
      cachedBalanceCents: 24850,
      lifetimeTransactionCount: 642,
      manualOfflineWalletCents: 5000,
      policyVersion: 'v3.2026-04-22',
      modelVersion: 'credit-v1-demo',
      features: CreditModelFeatures(
        txCount30d: 78,
        txCount90d: 221,
        avgTxAmount30d: 18.4,
        medianTxAmount30d: 10.8,
        txAmountP95_30d: 62.0,
        uniquePayees30d: 17,
        uniquePayees90d: 39,
        payeeDiversityIndex: 1.72,
        reloadFreq30d: 4,
        reloadAmountAvg: 84.0,
        daysSinceLastReload: 6,
        timeOfDayPrimary: 13,
        weekdayShare: 0.74,
        geoDispersionKm: 5.8,
        priorOfflineCount: 22,
        priorOfflineSettleRate: 0.99,
        accountAgeDays: 780,
        kycTier: 2,
        deviceAttestOk: 1,
      ),
    );
  }

  final int cachedBalanceCents;
  final int lifetimeTransactionCount;
  final int manualOfflineWalletCents;
  final String policyVersion;
  final String modelVersion;
  final CreditModelFeatures features;

  int get kycTier => features.kycTier.round().clamp(0, 2);
}

class CreditScoreDriver {
  const CreditScoreDriver({
    required this.label,
    required this.value,
    required this.isPositive,
  });

  final String label;
  final String value;
  final bool isPositive;
}

class CreditScoreDecision {
  const CreditScoreDecision({
    required this.cachedBalanceCents,
    required this.safeOfflineBalanceCents,
    required this.hardCapCents,
    required this.lastSyncAgeMinutes,
    required this.confidence,
    required this.policyVersion,
    required this.modelVersion,
    required this.isAiEligible,
    required this.lifetimeTransactionCount,
    required this.drivers,
    required this.featureVector,
  });

  final int cachedBalanceCents;
  final int safeOfflineBalanceCents;
  final int hardCapCents;
  final int lastSyncAgeMinutes;
  final double confidence;
  final String policyVersion;
  final String modelVersion;
  final bool isAiEligible;
  final int lifetimeTransactionCount;
  final List<CreditScoreDriver> drivers;
  final List<double> featureVector;

  int availableSafeBalanceCents({required int pendingOutgoingCents}) {
    return math.max(0, safeOfflineBalanceCents - pendingOutgoingCents);
  }

  List<CreditScoreDriver> panelDrivers({required int pendingOutgoingCents}) {
    if (pendingOutgoingCents <= 0) {
      return drivers;
    }

    return <CreditScoreDriver>[
      ...drivers,
      CreditScoreDriver(
        label: 'Pending settlement',
        value: '${_formatMyr(pendingOutgoingCents)} already committed',
        isPositive: false,
      ),
    ];
  }
}

class CreditScorer {
  const CreditScorer();

  CreditScoreDecision score({
    required OfflineWalletProfile profile,
    required int lastSyncAgeMinutes,
  }) {
    final boundedSyncAge = math.max(0, lastSyncAgeMinutes);
    final features =
        profile.features.toVector(lastSyncAgeMinutes: boundedSyncAge);
    final hardCapCents = _hardCapForTier(profile.kycTier);

    if (profile.lifetimeTransactionCount < 600) {
      final manualLimit = math.min(
        profile.manualOfflineWalletCents,
        math.min(profile.cachedBalanceCents, hardCapCents),
      );
      return CreditScoreDecision(
        cachedBalanceCents: profile.cachedBalanceCents,
        safeOfflineBalanceCents: manualLimit,
        hardCapCents: hardCapCents,
        lastSyncAgeMinutes: boundedSyncAge,
        confidence: 0,
        policyVersion: profile.policyVersion,
        modelVersion: profile.modelVersion,
        isAiEligible: false,
        lifetimeTransactionCount: profile.lifetimeTransactionCount,
        drivers: <CreditScoreDriver>[
          CreditScoreDriver(
            label: 'History building',
            value: '${profile.lifetimeTransactionCount}/600 tx completed',
            isPositive: false,
          ),
          CreditScoreDriver(
            label: 'Manual offline wallet',
            value: _formatMyr(profile.manualOfflineWalletCents),
            isPositive: true,
          ),
        ],
        featureVector: features,
      );
    }

    // This keeps the same 20-feature vector + clamp contract as the future
    // TF Lite runtime, while the generated model artifact is still pending.
    final rawSafeMyr = 52.58 +
        (_normalized(features[0], 90) * 8.0) +
        (_normalized(features[15], 1.0) * 24.0) +
        (_normalized(features[16], 720) * 16.0) +
        (_normalized(features[17], 2.0) * 10.0) +
        (_normalized(features[14], 36.0) * 8.0) +
        (features[19] > 0.5 ? 6.0 : -20.0) -
        (math.min(features[18], 60) * 0.35) -
        (math.max(features[4] - 60, 0) * 0.08);

    final confidence = (0.58 +
            (_normalized(features[15], 1.0) * 0.14) +
            (_normalized(features[16], 720) * 0.08) +
            (features[19] > 0.5 ? 0.07 : -0.18) -
            (_normalized(features[18], 60) * 0.12))
        .clamp(0.0, 0.99);

    final modelOutCents = math.max(0, (rawSafeMyr * 100).round());
    final clampedSafeBalance = math.min(
      modelOutCents,
      math.min(profile.cachedBalanceCents, hardCapCents),
    );

    return CreditScoreDecision(
      cachedBalanceCents: profile.cachedBalanceCents,
      safeOfflineBalanceCents: clampedSafeBalance,
      hardCapCents: hardCapCents,
      lastSyncAgeMinutes: boundedSyncAge,
      confidence: confidence,
      policyVersion: profile.policyVersion,
      modelVersion: profile.modelVersion,
      isAiEligible: true,
      lifetimeTransactionCount: profile.lifetimeTransactionCount,
      drivers: <CreditScoreDriver>[
        CreditScoreDriver(
          label: 'Clean offline history',
          value:
              '${(profile.features.priorOfflineSettleRate * 100).round()}% settled clean',
          isPositive: true,
        ),
        CreditScoreDriver(
          label: 'Account trust',
          value:
              '${profile.features.accountAgeDays.round()} days · Tier ${profile.kycTier}',
          isPositive: true,
        ),
        CreditScoreDriver(
          label: 'Recent activity',
          value: '${profile.features.txCount30d.round()} tx in 30d',
          isPositive: true,
        ),
        CreditScoreDriver(
          label: 'Last sync age',
          value: '$boundedSyncAge min old',
          isPositive: false,
        ),
      ],
      featureVector: features,
    );
  }

  int _hardCapForTier(int tier) {
    switch (tier) {
      case 0:
        return 2000;
      case 1:
        return 5000;
      default:
        return 25000;
    }
  }

  double _normalized(double value, double maxValue) {
    if (maxValue <= 0) {
      return 0;
    }

    return (value / maxValue).clamp(0.0, 1.0);
  }
}

String _formatMyr(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return 'RM $whole.$fraction';
}
