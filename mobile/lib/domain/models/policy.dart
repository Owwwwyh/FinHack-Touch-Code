/// Domain model for score policy.
class Policy {
  final String policyVersion;
  final DateTime releasedAt;
  final String modelFormat;
  final String modelUrl;
  final String modelSha256;
  final String? sigstoreSignature;
  final Map<String, String> hardCapPerTier;
  final String globalCapPerTokenMyr;
  final int maxTokenValidityHours;

  Policy({
    required this.policyVersion,
    required this.releasedAt,
    required this.modelFormat,
    required this.modelUrl,
    required this.modelSha256,
    this.sigstoreSignature,
    required this.hardCapPerTier,
    required this.globalCapPerTokenMyr,
    this.maxTokenValidityHours = 72,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      policyVersion: json['policy_version'] as String,
      releasedAt: DateTime.parse(json['released_at'] as String),
      modelFormat: json['model']['format'] as String,
      modelUrl: json['model']['url'] as String,
      modelSha256: json['model']['sha256'] as String,
      sigstoreSignature: json['model']['sigstore_signature'] as String?,
      hardCapPerTier: (json['limits']['hard_cap_per_tier'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String)),
      globalCapPerTokenMyr: json['limits']['global_cap_per_token_myr'] as String,
      maxTokenValidityHours: json['limits']['max_token_validity_hours'] as int? ?? 72,
    );
  }

  /// Get hard cap for a given KYC tier (0, 1, 2).
  int hardCapCentsForTier(int tier) {
    final key = tier.toString();
    final myr = hardCapPerTier[key] ?? '20.00';
    return (double.parse(myr) * 100).round();
  }
}
