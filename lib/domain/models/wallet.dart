// lib/domain/models/wallet.dart

/// The user's wallet state, as cached from the server.
class WalletState {
  const WalletState({
    required this.userId,
    required this.balanceMyr,
    required this.safeOfflineMyr,
    required this.syncedAt,
    required this.policyVersion,
    required this.riskScore,
  });

  final String userId;
  final double balanceMyr;
  final double safeOfflineMyr;
  final DateTime syncedAt;
  final String policyVersion;
  final String riskScore;

  /// The displayable safe offline balance (may be lowered by local spending).
  double get displaySafeOffline => safeOfflineMyr;

  WalletState copyWith({
    double? balanceMyr,
    double? safeOfflineMyr,
    DateTime? syncedAt,
    String? policyVersion,
    String? riskScore,
  }) => WalletState(
    userId:         userId,
    balanceMyr:     balanceMyr     ?? this.balanceMyr,
    safeOfflineMyr: safeOfflineMyr ?? this.safeOfflineMyr,
    syncedAt:       syncedAt       ?? this.syncedAt,
    policyVersion:  policyVersion  ?? this.policyVersion,
    riskScore:      riskScore      ?? this.riskScore,
  );

  /// Demo / initial state.
  static WalletState demo() => WalletState(
    userId:         'u_demo',
    balanceMyr:     248.50,
    safeOfflineMyr: 120.00,
    syncedAt:       DateTime.now(),
    policyVersion:  'v1.demo',
    riskScore:      'LOW',
  );
}

/// Result of an AI risk scoring operation.
class RiskScoreResult {
  const RiskScoreResult({
    required this.riskScore,
    required this.safeOfflineLimit,
  });

  final String riskScore; // 'LOW' | 'MEDIUM' | 'HIGH'
  final double safeOfflineLimit;
}
