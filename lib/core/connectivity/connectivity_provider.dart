import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'connectivity_state.dart';

final connectivityServiceProvider =
    StateNotifierProvider<ConnectivityService, ConnectivityViewState>((ref) {
  return ConnectivityService();
});
