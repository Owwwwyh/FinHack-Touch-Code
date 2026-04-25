// lib/core/di/providers.dart
//
// Riverpod provider definitions for the whole app.
// All domain state flows through these providers.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/wallet.dart';
import '../connectivity/connectivity_service.dart';

// Re-export connectivity providers
export '../connectivity/connectivity_service.dart'
    show connectivityServiceProvider, isOfflineProvider;

import '../../data/api/wallet_api.dart';
import '../../data/api/devices_api.dart';
import '../../data/api/tokens_api.dart';

// ─── API Providers ────────────────────────────────────────────────────────────

final walletApiProvider = Provider((ref) => WalletApi());
final devicesApiProvider = Provider((ref) => DevicesApi());
final tokensApiProvider = Provider((ref) => TokensApi());

// ─── Wallet State ─────────────────────────────────────────────────────────────

/// Mutable wallet state (balance + safe offline).
/// In Phase 2 this is demo data; Phase 3 hooks into API.
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletApi _api;
  WalletNotifier(this._api) : super(WalletState.demo());

  /// Fetch authoritative balance from server.
  Future<void> syncBalance() async {
    try {
      final newState = await _api.getBalance(state.userId);
      state = newState;
    } catch (e) {
      // In a real app, handle error (e.g., show snackbar)
    }
  }

  /// Trigger AI risk scoring.
  Future<void> refreshAIScore() async {
    try {
      final result = await _api.refreshSafeLimit(state.userId, {});
      state = state.copyWith(
        safeOfflineMyr: result.safeOfflineLimit,
        riskScore:      result.riskScore,
      );
    } catch (e) {
      // Handle error
    }
  }

  /// Called after a successful /wallet/balance response.
  void updateFromServer({
    required double balanceMyr,
    required double safeOfflineMyr,
    required String policyVersion,
  }) {
    state = state.copyWith(
      balanceMyr:     balanceMyr,
      safeOfflineMyr: safeOfflineMyr,
      syncedAt:       DateTime.now(),
      policyVersion:  policyVersion,
    );
  }

  /// Optimistic local decrement when a token is signed.
  /// The server balance is authoritative; this is only for UX feedback.
  void decrementSafeBalance(double amountMyr) {
    final newSafe = (state.safeOfflineMyr - amountMyr).clamp(0.0, state.balanceMyr);
    state = state.copyWith(safeOfflineMyr: newSafe);
  }

  /// Restore safe balance if a token was rejected.
  void restoreSafeBalance(double amountMyr) {
    final newSafe = (state.safeOfflineMyr + amountMyr).clamp(0.0, state.balanceMyr);
    state = state.copyWith(safeOfflineMyr: newSafe);
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>(
  (ref) => WalletNotifier(ref.watch(walletApiProvider)),
);

// ─── Pending token count ───────────────────────────────────────────────────────

/// Stub: in Phase 2 this will watch the Drift outbox.
final pendingCountProvider = StateProvider<int>((ref) => 0);

// ─── NFC simulation mode ──────────────────────────────────────────────────────

/// True = use the NFC simulator (no real NFC hardware required for demo).
final nfcSimModeProvider = StateProvider<bool>((ref) => false);

// ─── Pay screen state ─────────────────────────────────────────────────────────

enum NfcTapState { idle, detecting, transferring, done, failed }

class PayScreenNotifier extends StateNotifier<NfcTapState> {
  PayScreenNotifier() : super(NfcTapState.idle);

  void reset()       => state = NfcTapState.idle;
  void detecting()   => state = NfcTapState.detecting;
  void transferring()=> state = NfcTapState.transferring;
  void done()        => state = NfcTapState.done;
  void failed()      => state = NfcTapState.failed;
}

final payScreenProvider = StateNotifierProvider.autoDispose<PayScreenNotifier, NfcTapState>(
  (ref) => PayScreenNotifier(),
);
