import 'dart:math';

import '../core/types.dart';

const _hold = Duration(seconds: 2);

/// The room light must be on: lux above the threshold for 2 s in a row.
class LightsDetector {
  LightsDetector({double? calibratedLux})
    : threshold = calibratedLux == null ? 30 : max(10, calibratedLux / 2);

  final double threshold;
  Duration? _brightSince;
  bool _passed = false;

  ChallengeProgress onLux(double lux, Duration t) {
    if (_passed) return ChallengeProgress.complete;
    if (lux < threshold) {
      _brightSince = null;
      return ChallengeProgress.none;
    }
    final held = t - (_brightSince ??= t);
    if (held >= _hold) {
      _passed = true;
      return ChallengeProgress.complete;
    }
    return ChallengeProgress(held.inMilliseconds / _hold.inMilliseconds);
  }
}
