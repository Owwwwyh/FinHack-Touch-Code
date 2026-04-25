import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_policy.dart';
import 'connectivity_state.dart';

typedef Now = DateTime Function();

class ConnectivityService extends StateNotifier<ConnectivityViewState> {
  ConnectivityService({
    ConnectivityPolicy policy = const ConnectivityPolicy(),
    Now? now,
    Duration heartbeat = const Duration(minutes: 1),
  }) : this._internal(
          policy: policy,
          now: now ?? DateTime.now,
          heartbeat: heartbeat,
        );

  ConnectivityService._internal({
    required ConnectivityPolicy policy,
    required Now now,
    required Duration heartbeat,
  })  : _policy = policy,
        _now = now,
        _heartbeat = heartbeat,
        _lastSyncedAt = now(),
        super(
          const ConnectivityViewState(
            tier: ConnectivityTier.online,
            hasNetwork: true,
            lastSyncedAt: null,
            consecutiveSyncFailures: 0,
          ),
        ) {
    _recompute();
    _ticker = Timer.periodic(_heartbeat, (_) => _recompute());
  }

  final ConnectivityPolicy _policy;
  final Now _now;
  final Duration _heartbeat;

  Timer? _ticker;
  DateTime? _lastSyncedAt;
  int _consecutiveSyncFailures = 0;
  bool _hasNetwork = true;

  void setNetworkAvailable(bool value) {
    _hasNetwork = value;
    _recompute();
  }

  void markSyncSuccess() {
    _lastSyncedAt = _now();
    _consecutiveSyncFailures = 0;
    _recompute();
  }

  void markSyncFailure() {
    _consecutiveSyncFailures += 1;
    _recompute();
  }

  void ageLastSyncBy(Duration age) {
    _lastSyncedAt = _now().subtract(age);
    _recompute();
  }

  void _recompute() {
    final now = _now();
    state = ConnectivityViewState(
      tier: _policy.evaluateTier(
        hasNetwork: _hasNetwork,
        lastSyncedAt: _lastSyncedAt,
        consecutiveSyncFailures: _consecutiveSyncFailures,
        now: now,
      ),
      hasNetwork: _hasNetwork,
      lastSyncedAt: _lastSyncedAt,
      consecutiveSyncFailures: _consecutiveSyncFailures,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
