/// Domain model for wallet state.
class Wallet {
  final String userId;
  final int balanceCents;
  final int safeOfflineCents;
  final int version;
  final DateTime syncedAt;
  final String policyVersion;
  final String currency;

  Wallet({
    required this.userId,
    required this.balanceCents,
    required this.safeOfflineCents,
    required this.version,
    required this.syncedAt,
    required this.policyVersion,
    this.currency = 'MYR',
  });

  /// Formatted balance string.
  String get balanceMyr => '${(balanceCents / 100).toStringAsFixed(2)}';

  /// Formatted safe offline balance string.
  String get safeOfflineMyr => '${(safeOfflineCents / 100).toStringAsFixed(2)}';

  Wallet copyWith({
    int? balanceCents,
    int? safeOfflineCents,
    int? version,
    DateTime? syncedAt,
    String? policyVersion,
  }) {
    return Wallet(
      userId: userId,
      balanceCents: balanceCents ?? this.balanceCents,
      safeOfflineCents: safeOfflineCents ?? this.safeOfflineCents,
      version: version ?? this.version,
      syncedAt: syncedAt ?? this.syncedAt,
      policyVersion: policyVersion ?? this.policyVersion,
      currency: currency,
    );
  }
}
