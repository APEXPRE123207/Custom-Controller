import 'package:flutter/services.dart';

enum HapticIntensity { light, medium, heavy }

/// Manages tactile haptic feedback and vibrations with customizable on/off toggle.
class HapticService {
  static final HapticService instance = HapticService._internal();
  HapticService._internal();

  bool isEnabled = true;
  HapticIntensity intensity = HapticIntensity.light;

  /// Trigger button press haptic feedback
  void triggerButton() {
    if (!isEnabled) return;
    switch (intensity) {
      case HapticIntensity.light:
        // Delicate subtle tick - lowest vibration
        HapticFeedback.selectionClick();
        break;
      case HapticIntensity.medium:
        // Crisp, distinct tap - medium vibration
        HapticFeedback.mediumImpact();
        break;
      case HapticIntensity.heavy:
        // Full, powerful motor vibration - strongest vibration
        HapticFeedback.vibrate();
        break;
    }
  }

  /// Trigger subtle stick movement / click feedback
  void triggerTick() {
    if (!isEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// Trigger trigger press
  void triggerHeavy() {
    if (!isEnabled) return;
    HapticFeedback.vibrate();
  }
}
