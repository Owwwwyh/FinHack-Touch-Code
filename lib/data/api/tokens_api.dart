// lib/data/api/tokens_api.dart
import 'dart:async';
import '../../domain/models/token.dart';

class TokensApi {
  /// Mock submitting a batch of JWS tokens for settlement.
  Future<List<SettlementResult>> settle(List<String> tokens) async {
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Simulate server processing each token in the batch
    return tokens.map((jws) {
      // In a real scenario, we'd decode the JWS to get the txId.
      // Here we just return a success for the demo.
      return SettlementResult(
        txId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        status: 'SETTLED',
        settledAt: DateTime.now(),
      );
    }).toList();
  }
}
