import 'dart:math';
import 'dart:typed_data';

/// TF Lite credit scorer wrapper for on-device inference.
/// Computes safe_offline_balance from 20-feature input vector.
class CreditScorer {
  bool _isLoaded = false;

  /// Load the TF Lite model from assets.
  Future<void> loadModel() async {
    // TODO: Implement with tflite_flutter when model is available
    _isLoaded = true;
  }

  /// Run inference on the 20-element feature vector.
  /// Returns the safe_offline_balance in MYR cents.
  Future<double> predict(List<double> features) async {
    if (!_isLoaded) await loadModel();

    // Placeholder: simple heuristic until TF Lite model is loaded
    // f01=tx_count_30d, f17=account_age_days, f19=last_sync_age_min
    final txCount = features[0]; // f01
    final accountAge = features[16]; // f17
    final syncAge = features[18]; // f19
    final kycTier = features[17]; // f18

    // Base: 5% of typical balance, boosted by activity
    double base = 5000; // RM 50 base
    base += txCount * 100; // RM 1 per recent tx
    base += accountAge * 0.5; // slight boost for older accounts
    base -= syncAge * 50; // decay with sync age
    base *= (1 + kycTier * 0.5); // KYC tier multiplier

    return max(0, base);
  }

  /// Build the 20-feature vector from local aggregates.
  List<double> buildFeatureVector({
    required int txCount30d,
    required int txCount90d,
    required double avgTxAmount30d,
    required double medianTxAmount30d,
    required double txAmountP9530d,
    required int uniquePayees30d,
    required int uniquePayees90d,
    required double payeeDiversityIdx,
    required int reloadFreq30d,
    required double reloadAmountAvg,
    required int daysSinceLastReload,
    required int timeOfDayPrimary,
    required double weekdayShare,
    required double geoDispersionKm,
    required int priorOfflineCount,
    required double priorOfflineSettleRate,
    required int accountAgeDays,
    required int kycTier,
    required int lastSyncAgeMin,
    required int deviceAttestOk,
  }) {
    return [
      txCount30d.toDouble(), // f01
      txCount90d.toDouble(), // f02
      avgTxAmount30d, // f03
      medianTxAmount30d, // f04
      txAmountP9530d, // f05
      uniquePayees30d.toDouble(), // f06
      uniquePayees90d.toDouble(), // f07
      payeeDiversityIdx, // f08
      reloadFreq30d.toDouble(), // f09
      reloadAmountAvg, // f10
      daysSinceLastReload.toDouble(), // f11
      timeOfDayPrimary.toDouble(), // f12
      weekdayShare, // f13
      geoDispersionKm, // f14
      priorOfflineCount.toDouble(), // f15
      priorOfflineSettleRate, // f16
      accountAgeDays.toDouble(), // f17
      kycTier.toDouble(), // f18
      lastSyncAgeMin.toDouble(), // f19
      deviceAttestOk.toDouble(), // f20
    ];
  }
}
