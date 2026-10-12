import 'dart:math';

import '../core/types.dart';

/// Steps arriving faster than this are the phone being shaken, not walking.
const minStepInterval = Duration(milliseconds: 250);

/// Walk at least 80% of the calibrated bed-to-spot distance (minimum 10).
class WalkDetector {
  WalkDetector({int? calibratedSteps})
    : required = max(10, (0.8 * (calibratedSteps ?? 20)).ceil());

  final int required;
  int _counted = 0;
  Duration? _last;

  int get counted => _counted;

  ChallengeProgress onStep(Duration t) {
    final last = _last;
    if (_counted < required && (last == null || t - last >= minStepInterval)) {
      _counted++;
      _last = t;
    }
    return _counted >= required
        ? ChallengeProgress.complete
        : ChallengeProgress(_counted / required);
  }
}
