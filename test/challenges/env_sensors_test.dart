import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('byebyesleep/sensors');
  const light = EventChannel('byebyesleep/light');
  const steps = EventChannel('byebyesleep/steps');
  const pressure = EventChannel('byebyesleep/pressure');
  const proximity = EventChannel('byebyesleep/proximity');
  final source = ChannelEnvSensorSource(requestPermission: () async => true);

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(light, null);
    messenger.setMockStreamHandler(steps, null);
    messenger.setMockStreamHandler(pressure, null);
    messenger.setMockStreamHandler(proximity, null);
  });

  test('channel source maps lux and step events', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (call) async => ['light', 'stepDetector'],
    );
    messenger.setMockStreamHandler(
      light,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success(12.5);
          sink.success(300);
          sink.endOfStream();
        },
      ),
    );
    messenger.setMockStreamHandler(
      steps,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success(2000000000); // 2 s in nanoseconds
          sink.endOfStream();
        },
      ),
    );
    expect(await source.lux.toList(), [12.5, 300.0]);
    expect(await source.steps.toList(), [const Duration(seconds: 2)]);
  });

  test('available maps native sensor names', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (call) async =>
          call.method == 'available' ? ['light', 'stepDetector'] : null,
    );
    expect(await source.available(), {
      SensorKind.light,
      SensorKind.stepDetector,
    });
  });

  test('missing plugin → no sensors and empty streams', () async {
    expect(await source.available(), isEmpty);
    expect(await source.lux.toList(), isEmpty);
  });

  test('barometer and proximity are mapped and streamed', () async {
    messenger.setMockMethodCallHandler(
      methods,
      (call) async =>
          call.method == 'available' ? ['barometer', 'proximity'] : null,
    );
    messenger.setMockStreamHandler(
      pressure,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success(1013.25);
          sink.endOfStream();
        },
      ),
    );
    messenger.setMockStreamHandler(
      proximity,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          sink.success(true);
          sink.success(false);
          sink.endOfStream();
        },
      ),
    );
    expect(await source.available(), {
      SensorKind.barometer,
      SensorKind.proximity,
    });
    expect(await source.pressure.toList(), [1013.25]);
    expect(await source.proximityNear.toList(), [true, false]);
  });
}
