import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticHelper {
  /// Medium impact used to confirm a scan.
  ///
  /// iOS: [HapticFeedback] (UIFeedbackGenerator) is silenced by the system
  /// while the camera capture session is running, so the scan haptic would
  /// never fire. The `vibration` package uses CHHapticEngine instead, which
  /// keeps working with the camera active.
  ///
  /// Android: two vibration because
  /// - [HapticFeedback] works while the camera is active, but since
  ///   Android 13 it is silenced when the system "touch feedback" setting
  ///   is off.
  /// - The `vibration` package (Vibrator API) ignores that setting, but on
  ///   some devices the vibrator is muted while a camera session is active.
  /// Firing both at once just feels like a single buzz.
  /// On some device, it might not give any vibration at all...
  static Future<void> impact() async {
    try {
      if (Platform.isAndroid) {
        await HapticFeedback.vibrate();
      }
      await Vibration.vibrate(duration: 80, amplitude: 120);
    } catch (e) {
      debugPrint('HapticHelper: vibrate failed: $e');
    }
  }

  /// Two quick pulses, used when the scanned product is not vegan.
  ///
  /// Reuses [impact] for each pulse so both feel identical and go through
  /// the same camera-safe channels. The vibrate calls return as soon as
  /// the pulse is scheduled, so the delay covers the 80ms pulse plus a
  /// clearly perceptible gap.
  static Future<void> doubleImpact() async {
    await impact();
    await Future.delayed(const Duration(milliseconds: 180));
    await impact();
  }
}
