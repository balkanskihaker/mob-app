import 'package:flutter/foundation.dart';

/// Global navigation state manager
class AppNavigationState {
  /// Currently active recipe (if any)
  final ValueNotifier<Map<String, String>?> activeRecipe = ValueNotifier(null);

  /// Currently requested tab index
  final ValueNotifier<int> currentTab = ValueNotifier(0);

  /// Switch to a specific tab and optionally clear active recipe
  void switchTab(int index, {bool clearRecipe = true}) {
    if (clearRecipe) {
      activeRecipe.value = null;
    }
    currentTab.value = index;
  }
}

// Single global instance
final appState = AppNavigationState();
