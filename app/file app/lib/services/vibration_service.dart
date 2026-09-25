import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

abstract final class VibrationService {
  static Future<void> tocco() async {
    try {
      final bool disponibile = await Vibration.hasVibrator();

      if (!disponibile) {
        await HapticFeedback.mediumImpact();
        return;
      }

      final bool controlloIntensita = await Vibration.hasAmplitudeControl();

      if (controlloIntensita) {
        await Vibration.vibrate(duration: 100, amplitude: 220);
      } else {
        await Vibration.vibrate(duration: 120);
      }
    } catch (_) {
      await HapticFeedback.mediumImpact();
    }
  }

  static Future<void> pressioneProlungata() async {
    try {
      final bool disponibile = await Vibration.hasVibrator();

      if (!disponibile) {
        await HapticFeedback.heavyImpact();
        return;
      }

      final bool controlloIntensita = await Vibration.hasAmplitudeControl();

      if (controlloIntensita) {
        await Vibration.vibrate(
          pattern: <int>[0, 180, 70, 250],
          intensities: <int>[0, 255, 0, 255],
        );
      } else {
        await Vibration.vibrate(pattern: <int>[0, 200, 80, 300]);
      }
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> successo() async {
    try {
      final bool disponibile = await Vibration.hasVibrator();

      if (!disponibile) {
        await HapticFeedback.heavyImpact();
        return;
      }

      await Vibration.vibrate(
        pattern: <int>[0, 100, 70, 180],
        intensities: <int>[0, 180, 0, 255],
      );
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> errore() async {
    try {
      final bool disponibile = await Vibration.hasVibrator();

      if (!disponibile) {
        await HapticFeedback.vibrate();
        return;
      }

      await Vibration.vibrate(
        pattern: <int>[0, 150, 80, 150, 80, 250],
        intensities: <int>[0, 255, 0, 255, 0, 255],
      );
    } catch (_) {
      await HapticFeedback.vibrate();
    }
  }
}
