// lib/core/connectivity/connectivity_service.dart
//
// Implements the three-state connectivity machine:
//   ONLINE  ──(network lost OR 3x sync fail)──> STALE (0–10 min cache age)
//   STALE   ──(>10 min)──────────────────────> OFFLINE
//   OFFLINE ──(network back + sync OK)────────> ONLINE
//
// docs/07-mobile-app.md §5

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Connectivity State ───────────────────────────────────────────────────────

enum ConnectivityState {
  online,   // network present + last sync recent
  stale,    // network present OR recently lost, cache 0–10 min old
  offline,  // no network OR cache >10 min old
}

class WalletConnectivity {
  const WalletConnectivity({
    required this.state,
    required this.lastSyncedAt,
    this.syncFailCount = 0,
  });

  final ConnectivityState state;
  final DateTime? lastSyncedAt;
  final int syncFailCount;

  Duration get cacheAge =>
      lastSyncedAt != null
          ? DateTime.now().difference(lastSyncedAt!)
          : const Duration(days: 9999);

  String get statusLabel {
    return switch (state) {
      ConnectivityState.online  => 'Online · synced ${_prettyAge(cacheAge)} ago',
      ConnectivityState.stale   => 'Online · last sync ${_prettyAge(cacheAge)} ago',
      ConnectivityState.offline => 'Offline · last sync ${_prettyAge(cacheAge)} ago',
    };
  }

  static String _prettyAge(Duration d) {
    if (d.inSeconds < 10) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    return '${d.inHours}h';
  }

  WalletConnectivity copyWith({
    ConnectivityState? state,
    DateTime? lastSyncedAt,
    int? syncFailCount,
  }) => WalletConnectivity(
    state:        state        ?? this.state,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    syncFailCount: syncFailCount ?? this.syncFailCount,
  );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ConnectivityService extends StateNotifier<WalletConnectivity> {
  ConnectivityService()
      : super(const WalletConnectivity(
          state:       ConnectivityState.online,
          lastSyncedAt: null,
        )) {
    _startListening();
  }

  static const _staleDuration  = Duration(minutes: 10);

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _staleTimer;

  // ── Network monitoring ────────────────────────────────────────────────────

  void _startListening() {
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (!hasNetwork) {
      _enterOffline();
    } else if (state.state == ConnectivityState.offline) {
      // Reconnected — move to stale until a sync succeeds
      state = state.copyWith(state: ConnectivityState.stale);
    }
  }

  // ── Called by wallet service after a successful balance sync ─────────────

  void onSyncSuccess(DateTime syncedAt) {
    _staleTimer?.cancel();
    state = state.copyWith(
      state:         ConnectivityState.online,
      lastSyncedAt:  syncedAt,
      syncFailCount: 0,
    );
    // Start stale timer
    _staleTimer = Timer(_staleDuration, _enterStale);
  }

  // ── Called by wallet service after a sync failure ─────────────────────────

  void onSyncFailure() {
    final fails = state.syncFailCount + 1;
    if (fails >= 3) {
      _enterOffline();
    } else {
      state = state.copyWith(syncFailCount: fails);
    }
  }

  // ── State transitions ─────────────────────────────────────────────────────

  void _enterStale() {
    if (state.state == ConnectivityState.online) {
      state = state.copyWith(state: ConnectivityState.stale);
      // Start offline timer — another 10 min of stale = offline
      _staleTimer = Timer(_staleDuration, _enterOffline);
    }
  }

  void _enterOffline() {
    _staleTimer?.cancel();
    state = state.copyWith(state: ConnectivityState.offline);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _staleTimer?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final connectivityServiceProvider =
    StateNotifierProvider<ConnectivityService, WalletConnectivity>(
  (ref) => ConnectivityService(),
);

/// Convenience: is the app currently in offline state?
final isOfflineProvider = Provider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).state == ConnectivityState.offline,
);
