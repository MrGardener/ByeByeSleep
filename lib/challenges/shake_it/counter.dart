/// Shake it: count hard shakes from the accelerometer. Pure Dart.
library;

import 'dart:math';

import '../core/types.dart';

class ShakeCounter {
  ShakeCounter(this.target);

  /// 20 shakes at difficulty 1 … 60 at 5.
  factory ShakeCounter.forDifficulty(int difficulty) =>
      ShakeCounter(const [20, 30, 40, 50, 60][difficulty.clamp(1, 5) - 1]);

  /// A shake peaks above this (m/s², gravity included; resting is 9.8).
  static const high = 22.0;

  /// … and the phone must calm below this before the next one counts.
  static const low = 14.0;

  /// Peaks closer together than this are one jolt, not two shakes.
  static const minGap = Duration(milliseconds: 100);

  final int target;
  int count = 0;
  bool _armed = true;
  Duration? _last;

  bool get passed => count >= target;
  double get progress => min(1, count / target);

  /// Feeds one sample taken at [t]; true when it counted a shake.
  bool onAccel(Vec3 a, Duration t) {
    final m = sqrt(a.x * a.x + a.y * a.y + a.z * a.z);
    if (m <= low) {
      _armed = true;
      return false;
    }
    if (m < high || !_armed || passed) return false;
    _armed = false;
    final last = _last;
    if (last != null && t - last < minGap) return false;
    _last = t;
    count++;
    return true;
  }
}
