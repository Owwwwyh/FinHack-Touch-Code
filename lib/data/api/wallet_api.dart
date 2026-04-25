// lib/data/api/wallet_api.dart
import 'dart:async';
import '../../domain/models/wallet.dart';

class WalletApi {
  /// Mock fetching authoritative balance from the server.
  Future<WalletState> getBalance(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // For demo purposes, we return a slightly updated balance if it's the demo user
    return WalletState(
      userId: userId,
      balanceMyr: 248.50,
      safeOfflineMyr: 120.00,
      syncedAt: DateTime.now(),
      policyVersion: 'v3.2026-04-22',
    );
  }

  /// Mock refreshing the safe offline limit via AI score endpoint.
  /// Endpoint: /mock/risk-score
  Future<RiskScoreResult> refreshSafeLimit(String userId, Map<String, dynamic> features) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    return const RiskScoreResult(
      riskScore: 'LOW',
      safeOfflineLimit: 120.00,
    );
  }
}
