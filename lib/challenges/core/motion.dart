import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'types.dart';

/// Motion sensor streams, behind an interface so tests can inject samples.
abstract class MotionSource {
  /// Acceleration including gravity, m/s².
  Stream<Vec3> get accelerometer;

  /// Rotation rate, rad/s.
  Stream<Vec3> get gyroscope;

  /// Magnetic field, µT.
  Stream<Vec3> get magnetometer;

  /// Sensors that deliver data on this device.
  Future<Set<SensorKind>> available();
}

class SensorsPlusMotionSource implements MotionSource {
  // Game rate (~50 Hz): the plugin default (5 Hz) makes the maze lag and the
  // gyroscope integration drift.
  @override
  Stream<Vec3> get accelerometer =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => Vec3(e.x, e.y, e.z));

  @override
  Stream<Vec3> get gyroscope =>
      gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => Vec3(e.x, e.y, e.z));

  @override
  Stream<Vec3> get magnetometer =>
      magnetometerEventStream(samplingPeriod: SensorInterval.gameInterval)
          .map((e) => Vec3(e.x, e.y, e.z));

  @override
  Future<Set<SensorKind>> available() async {
    Future<bool> emits(Stream<Vec3> s) => s.first
        .timeout(const Duration(seconds: 1))
        .then((_) => true, onError: (Object _) => false);
    final results = await Future.wait([
      emits(accelerometer),
      emits(gyroscope),
      emits(magnetometer),
    ]);
    return {
      if (results[0]) SensorKind.accelerometer,
      if (results[1]) SensorKind.gyroscope,
      if (results[2]) SensorKind.magnetometer,
    };
  }
}

final motionSourceProvider = Provider<MotionSource>(
  (_) => SensorsPlusMotionSource(),
);
