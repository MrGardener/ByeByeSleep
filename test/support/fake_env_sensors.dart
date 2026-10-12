import 'dart:async';

import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/types.dart';

/// Light and step readings driven by the test.
class FakeEnvSensors implements EnvSensorSource {
  FakeEnvSensors({
    this.availableKinds = const {SensorKind.light, SensorKind.stepDetector},
    this.permissionGranted = true,
  });

  final Set<SensorKind> availableKinds;
  bool permissionGranted;
  final luxController = StreamController<double>.broadcast();
  final stepController = StreamController<Duration>.broadcast();

  @override
  Stream<double> get lux => luxController.stream;

  @override
  Stream<Duration> get steps => stepController.stream;

  @override
  Future<Set<SensorKind>> available() async => availableKinds;

  @override
  Future<bool> requestActivityPermission() async => permissionGranted;
}
