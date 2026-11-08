import 'dart:async';

import 'package:flutter/services.dart';

/// Light haptics on equip, jump, landing and bolt pickup (FEEL-02), using
/// Flutter's built-in HapticFeedback. Off when the Grown-ups switch is off.
class Haptics {
  const Haptics({required this.enabled});

  final bool enabled;

  void light() {
    if (enabled) unawaited(HapticFeedback.lightImpact());
  }

  void medium() {
    if (enabled) unawaited(HapticFeedback.mediumImpact());
  }
}
