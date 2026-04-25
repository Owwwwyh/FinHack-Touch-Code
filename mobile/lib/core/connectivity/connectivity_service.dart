import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityState { online, stale, offline }

final connectivityStateProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  late final Connectivity _connectivity;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  DateTime? _lastSyncAt;
  static const _staleThreshold = Duration(minutes: 10);

  ConnectivityNotifier() : super(ConnectivityState.online) {
    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      state = ConnectivityState.offline;
    } else if (_lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) > _staleThreshold) {
      state = ConnectivityState.stale;
    } else {
      state = ConnectivityState.online;
    }
  }

  void markSynced() {
    _lastSyncAt = DateTime.now();
    state = ConnectivityState.online;
  }

  void markSyncFailed() {
    // After 3 failures, go offline
    state = ConnectivityState.offline;
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
