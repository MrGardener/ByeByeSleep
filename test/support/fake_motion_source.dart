import 'dart:async';

import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';

/// Motion source driven by the test: push samples into the controllers.
class FakeMotionSource implements MotionSource {
  FakeMotionSource({
    this.availableKinds = const {
      SensorKind.accelerometer,
      SensorKind.gyroscope,
    },
  });

  final Set<SensorKind> availableKinds;
  final accel = StreamController<Vec3>.broadcast();
  final gyro = StreamController<Vec3>.broadcast();

  @override
  Stream<Vec3> get accelerometer => accel.stream;

  @override
  Stream<Vec3> get gyroscope => gyro.stream;

  @override
  Future<Set<SensorKind>> available() async => availableKinds;
}
