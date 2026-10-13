/// Wrist challenges from the watch's sensors. Pure Dart.
library;

/// Arm swings needed at [difficulty] 1–5.
int swingsFor(int difficulty) => 10 + 5 * difficulty.clamp(1, 5);

/// Steps needed at [difficulty] 1–5.
int stepsFor(int difficulty) => 15 * (difficulty.clamp(1, 5) + 1);

/// Counts arm swings in 10 Hz wrist acceleration: a swing is a peak above
/// [high] m/s², re-armed once the wrist calms below [low], at most one per
/// 0.3 s — so small movements and frantic shaking do not add up.
class SwingCounter {
  static const high = 12.0;
  static const low = 4.0;
  static const _minGap = 3; // samples at 10 Hz

  int swings = 0;
  bool _armed = true;
  int _sinceLast = _minGap;

  void add(double m) {
    _sinceLast++;
    if (_armed && m >= high && _sinceLast >= _minGap) {
      swings++;
      _armed = false;
      _sinceLast = 0;
    } else if (m <= low) {
      _armed = true;
    }
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
