import 'package:flutter/foundation.dart';

/// Global navigation state manager
class AppNavigationState {
  /// Currently active recipe (if any)
  final ValueNotifier<Map<String, String>?> activeRecipe = ValueNotifier(null);
  
  /// Currently requested tab index
  final ValueNotifier<int> currentTab = ValueNotifier(0);
  
  /// Whether a recipe is currently being cooked
  final ValueNotifier<bool> isCooking = ValueNotifier(false);
  
  /// Switch to a specific tab and optionally clear active recipe
  void switchTab(int index, {bool clearRecipe = true}) {
    if (clearRecipe) {
      activeRecipe.value = null;
    }
    currentTab.value = index;
  }

  /// Start cooking a recipe
  void startCooking(String id, String title) {
    activeRecipe.value = {'id': id, 'title': title};
    isCooking.value = true;
  }

  /// Stop cooking (either cancelled or finished)
  void stopCooking() {
    activeRecipe.value = null;
    isCooking.value = false;
  }
}

// Single global instance
final appState = AppNavigationState();