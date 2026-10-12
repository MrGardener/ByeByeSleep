import 'dart:math';

import '../core/types.dart';

enum PhoneOrientation {
  faceUp,
  faceDown,
  portrait,
  portraitUpsideDown,
  landscapeLeft,
  landscapeRight,
}

const _gravityThreshold = 7.0; // m/s² on one axis
const _holdTime = Duration(milliseconds: 300);

/// The orientation whose axis carries most of gravity, if clearly one.
PhoneOrientation? classifyOrientation(Vec3 g) {
  final ax = g.x.abs(), ay = g.y.abs(), az = g.z.abs();
  final top = max(ax, max(ay, az));
  if (top < _gravityThreshold) return null;
  if (top == az) {
    return g.z > 0 ? PhoneOrientation.faceUp : PhoneOrientation.faceDown;
  }
  if (top == ay) {
    return g.y > 0
        ? PhoneOrientation.portrait
        : PhoneOrientation.portraitUpsideDown;
  }
  return g.x > 0
      ? PhoneOrientation.landscapeLeft
      : PhoneOrientation.landscapeRight;
}

/// Turn the phone through a shown sequence of orientations, holding each
/// briefly, fast enough or the sequence restarts.
class HopscotchDetector {
  HopscotchDetector({required this.difficulty, required this.random})
    : stepLimit = const [
        Duration(seconds: 4),
        Duration(seconds: 3),
        Duration(milliseconds: 2500),
        Duration(seconds: 2),
        Duration(milliseconds: 1500),
      ][difficulty.clamp(1, 5) - 1] {
    final length = difficulty.clamp(1, 5) + 2;
    final seq = <PhoneOrientation>[];
    while (seq.length < length) {
      final o = PhoneOrientation
          .values[random.nextInt(PhoneOrientation.values.length)];
      if (seq.isEmpty || seq.last != o) seq.add(o);
    }
    sequence = List.unmodifiable(seq);
  }

  final int difficulty;
  final Random random;

  /// Time allowed to reach each step after the previous one.
  final Duration stepLimit;
  late final List<PhoneOrientation> sequence;
  int _step = 0;
  Duration? _holdStart;
  Duration? _lastStepAt;

  int get step => _step;
  PhoneOrientation? get target =>
      _step < sequence.length ? sequence[_step] : null;
  ChallengeProgress get progress => _step >= sequence.length
      ? ChallengeProgress.complete
      : ChallengeProgress(_step / sequence.length);

  /// Feed one accelerometer sample; [t] is a monotonic timestamp.
  ChallengeProgress onAccel(Vec3 a, Duration t) {
    if (progress.passed) return progress;
    final last = _lastStepAt;
    if (last != null && t - last > stepLimit) {
      _step = 0;
      _lastStepAt = null;
      _holdStart = null;
    }
    if (classifyOrientation(a) != target) {
      _holdStart = null;
      return progress;
    }
    final start = _holdStart ??= t;
    if (t - start >= _holdTime) {
      _step++;
      _lastStepAt = t;
      _holdStart = null;
    }
    return progress;
  }
}
