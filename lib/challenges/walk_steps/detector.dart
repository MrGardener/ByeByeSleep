import 'dart:math';

import '../core/types.dart';

/// A step event arriving sooner than this after the previous one is the
/// phone being shaken, not walking; it never counts.
const minStepInterval = Duration(milliseconds: 250);

/// Whether a step event at [t] counts, given the previous raw event.
bool isRealStep(Duration? previousEvent, Duration t) =>
    previousEvent == null || t - previousEvent >= minStepInterval;

/// Walk at least 80% of the calibrated bed-to-spot distance (minimum 10).
class WalkDetector {
  WalkDetector({int? calibratedSteps})
    : required = max(10, (0.8 * (calibratedSteps ?? 20)).ceil());

  final int required;
  int _counted = 0;
  Duration? _previousEvent;

  int get counted => _counted;

  ChallengeProgress onStep(Duration t) {
    if (_counted < required && isRealStep(_previousEvent, t)) _counted++;
    _previousEvent = t;
    return _counted >= required
        ? ChallengeProgress.complete
        : ChallengeProgress(_counted / required);
  }
}
