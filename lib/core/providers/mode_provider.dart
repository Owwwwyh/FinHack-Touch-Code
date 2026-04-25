// lib/core/providers/mode_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { online, offline }

class ModeNotifier extends StateNotifier<AppMode> {
  ModeNotifier() : super(AppMode.online);

  void toggleMode() {
    state = state == AppMode.online ? AppMode.offline : AppMode.online;
  }
  
  void setMode(AppMode mode) {
    state = mode;
  }
}

final modeProvider = StateNotifierProvider<ModeNotifier, AppMode>((ref) {
  return ModeNotifier();
});
