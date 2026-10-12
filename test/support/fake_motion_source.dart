import 'dart:async';

import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/sensors/trace.dart';

/// Motion source driven by the test: push samples into the controllers.
class FakeMotionSource implements MotionSource {
  FakeMotionSource({
    this.availableKinds = const {
      SensorKind.accelerometer,
      SensorKind.gyroscope,
    },
  }) : _trace = null;

  /// Source that replays a recorded trace when [replay] is called.
  FakeMotionSource.fromTrace(SensorTrace trace)
    : availableKinds = const {SensorKind.accelerometer, SensorKind.gyroscope},
      _trace = trace;

  final Set<SensorKind> availableKinds;
  final SensorTrace? _trace;

  /// Emits every trace sample in order, then closes the streams.
  Future<void> replay() async {
    for (final s in _trace?.samples ?? const <TraceSample>[]) {
      final v = Vec3(s.x, s.y, s.z);
      (s.sensor == 'gyroscope' ? gyro : accel).add(v);
    }
    await accel.close();
    await gyro.close();
  }

  final accel = StreamController<Vec3>.broadcast();
  final gyro = StreamController<Vec3>.broadcast();
  final mag = StreamController<Vec3>.broadcast();

  @override
  Stream<Vec3> get magnetometer => mag.stream;

  @override
  Stream<Vec3> get accelerometer => accel.stream;

  @override
  Stream<Vec3> get gyroscope => gyro.stream;

  @override
  Future<Set<SensorKind>> available() async => availableKinds;
}
