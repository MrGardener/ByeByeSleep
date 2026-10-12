import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'types.dart';

/// Ambient light, step detector, barometer and proximity, from the native `byebyesleep/sensors`
/// channels (Android). Behind an interface so tests can inject readings.
abstract class EnvSensorSource {
  /// Ambient light in lux.
  Stream<double> get lux;

  /// One event per detected step; monotonic timestamp.
  Stream<Duration> get steps;

  /// Air pressure in hPa.
  Stream<double> get pressure;

  /// True while something covers the proximity sensor.
  Stream<bool> get proximityNear;

  /// Subset of {light, stepDetector, barometer, proximity} on this device.
  Future<Set<SensorKind>> available();

  /// Asks for the "physical activity" permission the step detector needs.
  Future<bool> requestActivityPermission();
}

class ChannelEnvSensorSource implements EnvSensorSource {
  ChannelEnvSensorSource({Future<bool> Function()? requestPermission})
    : _requestPermission = requestPermission ?? _requestWithPlugin;

  static const _methods = MethodChannel('byebyesleep/sensors');
  static const _light = EventChannel('byebyesleep/light');
  static const _steps = EventChannel('byebyesleep/steps');
  static const _pressure = EventChannel('byebyesleep/pressure');
  static const _proximity = EventChannel('byebyesleep/proximity');

  final Future<bool> Function() _requestPermission;

  static Future<bool> _requestWithPlugin() async {
    try {
      return await _methods.invokeMethod<bool>('requestActivityPermission') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Native sensor errors are dropped so a challenge keeps listening.
  static Stream<Object?> _events(EventChannel c) => c
      .receiveBroadcastStream()
      .handleError((Object _) {}, test: (e) => e is PlatformException);

  // A missing native side never reports on the event stream itself, so
  // check the sensor exists first; otherwise the stream is empty.
  @override
  Stream<double> get lux async* {
    if (!(await available()).contains(SensorKind.light)) return;
    yield* _events(_light).map((e) => (e! as num).toDouble());
  }

  @override
  Stream<Duration> get steps async* {
    if (!(await available()).contains(SensorKind.stepDetector)) return;
    yield* _events(_steps)
        .map((e) => Duration(microseconds: (e! as int) ~/ 1000));
  }

  @override
  Stream<double> get pressure async* {
    if (!(await available()).contains(SensorKind.barometer)) return;
    yield* _events(_pressure).map((e) => (e! as num).toDouble());
  }

  @override
  Stream<bool> get proximityNear async* {
    if (!(await available()).contains(SensorKind.proximity)) return;
    yield* _events(_proximity).map((e) => e! as bool);
  }

  static const _kinds = {
    'light': SensorKind.light,
    'stepDetector': SensorKind.stepDetector,
    'barometer': SensorKind.barometer,
    'proximity': SensorKind.proximity,
  };

  @override
  Future<Set<SensorKind>> available() async {
    try {
      final names = await _methods.invokeListMethod<String>('available') ?? [];
      return {for (final n in names) ?_kinds[n]};
    } on MissingPluginException {
      return {};
    }
  }

  @override
  Future<bool> requestActivityPermission() => _requestPermission();
}

final envSensorProvider = Provider<EnvSensorSource>(
  (_) => ChannelEnvSensorSource(),
);
