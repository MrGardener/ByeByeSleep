/// Compass runes: face each compass point in turn and hold still. Pure Dart.
library;

import 'dart:math';

const _names = [
  'north',
  'north-east',
  'east',
  'south-east',
  'south',
  'south-west',
  'west',
  'north-west',
];

/// "north", "south-east"… for a heading that is a multiple of 45°.
String compassPointName(double heading) =>
    _names[((heading % 360) / 45).round() % 8];

/// Signed turn from [heading] to [target], −180..180 (positive = turn right).
double turnTo(double heading, double target) =>
    ((target - heading) % 360 + 540) % 360 - 180;

/// Face each target (±[tolerance]°) for [hold], in order. Wobbling off target
/// for up to [grace] keeps the hold; longer restarts it.
class CompassTrial {
  CompassTrial(
    this.targets, {
    this.tolerance = 20,
    this.hold = const Duration(seconds: 2),
    this.grace = const Duration(milliseconds: 600),
  });

  /// [count] compass points (multiples of 45°), each at least 90° from the
  /// one before, so every rune needs a real turn.
  /// With [from] (where you face now), the first one needs a turn too.
  static List<double> randomTargets(
    Random random, {
    int count = 4,
    double? from,
  }) {
    final far = [
      for (var i = 0; i < 8; i++)
        if (from == null || turnTo(from, i * 45.0).abs() >= 90) i * 45.0,
    ];
    final start = far[random.nextInt(far.length)];
    final out = <double>[start];
    while (out.length < count) {
      final steps = 2 + random.nextInt(5); // 90°…270°
      out.add((out.last + steps * 45) % 360);
    }
    return out;
  }

  final List<double> targets;
  final double tolerance;
  final Duration hold;
  final Duration grace;
  int index = 0;
  Duration held = Duration.zero;
  Duration? _onSince;
  Duration? _offSince;

  bool get passed => index >= targets.length;
  double? get target => passed ? null : targets[index];

  /// 0–1 for the rune being held.
  double get holdProgress =>
      (held.inMicroseconds / hold.inMicroseconds).clamp(0, 1).toDouble();

  double get progress => passed ? 1 : (index + holdProgress) / targets.length;

  bool isOn(double heading) =>
      !passed && turnTo(heading, targets[index]).abs() <= tolerance;

  void update(double heading, Duration now) {
    if (passed) return;
    final off = _offSince;
    if (isOn(heading)) {
      if (off != null && now - off > grace) _onSince = null;
      _offSince = null;
      final since = _onSince ??= now;
      held = now - since;
      if (held >= hold) {
        index++;
        held = Duration.zero;
        _onSince = null;
      }
    } else {
      final since = _offSince ??= now;
      if (now - since > grace) {
        _onSince = null;
        held = Duration.zero;
      }
    }
  }
}

/// Smooths compass readings (which jump around by 10–20°) without the
/// 359° → 1° wrap-around swinging the average to the south.
class HeadingFilter {
  HeadingFilter({this.alpha = 0.12});

  final double alpha;
  double? _sin;
  double? _cos;

  double? get heading {
    final s = _sin, c = _cos;
    if (s == null || c == null) return null;
    return (atan2(s, c) * 180 / pi + 360) % 360;
  }

  void add(double degrees) {
    final r = degrees * pi / 180;
    _sin = _sin == null ? sin(r) : _sin! + alpha * (sin(r) - _sin!);
    _cos = _cos == null ? cos(r) : _cos! + alpha * (cos(r) - _cos!);
  }
}
