import 'package:flutter/services.dart';

/// Touch feedback: a light tick per cell, a firmer tap at a knot.
class Haptics {
  bool enabled = true;

  void tick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  void knot() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  void clear() {
    if (enabled) HapticFeedback.heavyImpact();
  }
}
