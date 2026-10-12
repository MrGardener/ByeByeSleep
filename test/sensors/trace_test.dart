import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/sensors/trace_recorder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:byebyesleep/sensors/trace.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_motion_source.dart';

void main() {
  const trace = SensorTrace([
    TraceSample('accelerometer', 0, 0, 0, 9.8),
    TraceSample('gyroscope', 5000, 0, 0, 0.1),
    TraceSample('accelerometer', 20000, 1, 2, 9),
  ]);

  test('trace_jsonRoundTrip', () {
    final back = SensorTrace.fromJson(trace.toJson());
    expect(back.samples, hasLength(3));
    expect(back.samples[2].tMicros, 20000);
    expect(back.samples[2].y, 2);
    expect(back.samples[1].sensor, 'gyroscope');
  });

  test('fakeMotionSource_replaysTraceInOrder', () async {
    final source = FakeMotionSource.fromTrace(trace);
    final accel = source.accelerometer.toList();
    final gyro = source.gyroscope.toList();
    await source.replay();
    expect((await accel).map((v) => v.x), [0, 1]);
    expect((await gyro).single.z, 0.1);
    expect((await accel).first, isA<Vec3>());
  });

  testWidgets('recorder screen renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [motionSourceProvider.overrideWithValue(FakeMotionSource())],
        child: const MaterialApp(home: TraceRecorderScreen()),
      ),
    );
    expect(find.byKey(const Key('record-trace')), findsOneWidget);
  });
}
