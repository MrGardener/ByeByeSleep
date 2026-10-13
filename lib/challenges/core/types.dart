/// Plain types shared by challenge detectors. Pure Dart: no Flutter imports.
library;

class ChallengeProgress {
  const ChallengeProgress(this.value, {this.passed = false});

  static const ChallengeProgress none = ChallengeProgress(0);
  static const ChallengeProgress complete = ChallengeProgress(1, passed: true);

  /// 0.0–1.0
  final double value;
  final bool passed;

  @override
  bool operator ==(Object other) =>
      other is ChallengeProgress &&
      other.value == value &&
      other.passed == passed;

  @override
  int get hashCode => Object.hash(value, passed);

  @override
  String toString() => 'ChallengeProgress($value${passed ? ', passed' : ''})';
}

enum SensorKind {
  accelerometer,
  gyroscope,
  light,
  stepDetector,
  magnetometer,
  camera,
  nfc,
  battery,
  barometer,
  proximity,

  /// From the ByeByeSleep watch app.
  heartRate,
}

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  @override
  String toString() => 'Vec3($x, $y, $z)';
}
