import 'dart:async';

import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/types.dart';

/// Light, step, pressure and proximity readings driven by the test.
class FakeEnvSensors implements EnvSensorSource {
  FakeEnvSensors({
    this.availableKinds = const {SensorKind.light, SensorKind.stepDetector},
    this.permissionGranted = true,
  });

  final Set<SensorKind> availableKinds;
  bool permissionGranted;
  final luxController = StreamController<double>.broadcast();
  final stepController = StreamController<Duration>.broadcast();
  final pressureController = StreamController<double>.broadcast();
  final proximityController = StreamController<bool>.broadcast();

  @override
  Stream<double> get lux => luxController.stream;

  @override
  Stream<Duration> get steps => stepController.stream;

  @override
  Stream<double> get pressure => pressureController.stream;

  @override
  Stream<bool> get proximityNear => proximityController.stream;

  @override
  Future<Set<SensorKind>> available() async => availableKinds;

  @override
  Future<bool> requestActivityPermission() async => permissionGranted;
}
