/// Wrist challenges from the watch's sensors. Pure Dart.
library;

import 'dart:math';

/// Arm swings needed at [difficulty] 1–5.
int swingsFor(int difficulty) => 10 + 5 * difficulty.clamp(1, 5);

/// Steps needed at [difficulty] 1–5.
int stepsFor(int difficulty) => 15 * (difficulty.clamp(1, 5) + 1);

/// Counts arm swings in 10 Hz wrist acceleration (the strongest movement of
/// each 100 ms). A swing is a peak above [high] m/s². The next one counts once
/// the movement has eased off to [rearm] of that peak — a swinging arm never
/// stops between swings, so waiting for stillness would count only one — and
/// at most one per 0.3 s, so small movements and frantic shaking do not add up.
class SwingCounter {
  static const high = 12.0;
  static const low = 4.0;
  static const rearm = 0.65;
  static const _minGap = 3; // samples at 10 Hz

  int swings = 0;
  bool _armed = true;
  double _peak = 0;
  int _sinceLast = _minGap;

  void add(double m) {
    _sinceLast++;
    if (_armed) {
      if (m >= high && _sinceLast >= _minGap) {
        swings++;
        _armed = false;
        _peak = m;
        _sinceLast = 0;
      }
      return;
    }
    if (m > _peak) _peak = m;
    if (m <= max(low, _peak * rearm)) _armed = true;
  }

  void addAll(Iterable<double> ms) => ms.forEach(add);
}

/// Steps walked since the first reading the challenge saw.
class StepGoal {
  StepGoal(this.target);

  final int target;
  int? _base;
  int walked = 0;

  bool get passed => walked >= target;
  double get progress => (walked / target).clamp(0, 1).toDouble();

  void update(int counted) {
    final base = _base ??= counted;
    walked = counted - base < 0 ? 0 : counted - base;
  }
}
