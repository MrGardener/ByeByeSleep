import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/lights_on/detector.dart';
import 'package:byebyesleep/challenges/lights_on/setup.dart';
import 'package:byebyesleep/challenges/lights_on/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_env_sensors.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  test('lights_thresholdFromCalibration', () {
    expect(LightsDetector(calibratedLux: 200).threshold, 100);
    expect(LightsDetector(calibratedLux: 8).threshold, 10);
    expect(LightsDetector().threshold, 30);
  });

  test('lights_alreadyBrightPassesAfterHold', () {
    final d = LightsDetector();
    for (var t = 0; t <= 1900; t += 100) {
      expect(d.onLux(500, ms(t)).passed, isFalse);
    }
    expect(d.onLux(500, ms(2000)).passed, isTrue);
  });

  test('lights_dippingResetsHold', () {
    final d = LightsDetector();
    d.onLux(500, ms(0));
    d.onLux(500, ms(1500));
    expect(d.onLux(5, ms(1600)).value, 0);
    expect(d.onLux(500, ms(1700)).passed, isFalse);
    expect(d.onLux(500, ms(3600)).passed, isFalse);
    expect(d.onLux(500, ms(3700)).passed, isTrue);
  });

  testWidgets('lightsWidget_passesWithFakeLux', (tester) async {
    final sensors = FakeEnvSensors();
    var now = Duration.zero;
    var passed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [envSensorProvider.overrideWithValue(sensors)],
        child: MaterialApp(
          home: Scaffold(
            body: LightsChallenge(
              args: ChallengeArgs(
                difficulty: 2,
                random: Random(1),
                onPassed: () => passed++,
              ),
              elapsed: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var t = 0; t <= 2000; t += 500) {
      now = ms(t);
      sensors.luxController.add(400);
      await tester.pump();
    }
    expect(passed, 1);
  });

  testWidgets('lightsSetup_savesCurrentLux', (tester) async {
    final sensors = FakeEnvSensors();
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [envSensorProvider.overrideWithValue(sensors)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  saved = await setupLights(context, const {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    sensors.luxController.add(240);
    await tester.pump();
    await tester.pump();
    expect(find.text('240 lux'), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup-save')));
    await tester.pumpAndSettle();
    expect(saved, {'lux': 240.0});
  });
}
