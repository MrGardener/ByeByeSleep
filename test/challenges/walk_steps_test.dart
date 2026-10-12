import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/walk_steps/detector.dart';
import 'package:byebyesleep/challenges/walk_steps/setup.dart';
import 'package:byebyesleep/challenges/walk_steps/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_env_sensors.dart';

Duration ms(int v) => Duration(milliseconds: v);

Widget host(FakeEnvSensors sensors, Widget child) => ProviderScope(
  overrides: [envSensorProvider.overrideWithValue(sensors)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  test('walk_requiredIs80Percent', () {
    expect(WalkDetector(calibratedSteps: 25).required, 20);
    expect(WalkDetector(calibratedSteps: 5).required, 10);
    expect(WalkDetector().required, 16);
  });

  test('walk_shakingDoesNotCount', () {
    final d = WalkDetector();
    for (var i = 0; i <= 30; i++) {
      d.onStep(ms(i * 100)); // 10 "steps" per second
    }
    // 3 s of shaking → at most one step per 0.25 s, i.e. ≤ 13.
    expect(d.counted, lessThanOrEqualTo(13));
    expect(d.counted, greaterThan(0));
  });

  test('walk_normalPacePasses', () {
    final d = WalkDetector(calibratedSteps: 20);
    var passed = false;
    for (var i = 0; i < 16; i++) {
      passed = d.onStep(ms(i * 600)).passed;
    }
    expect(passed, isTrue);
  });

  testWidgets('walkWidget_passesWithFakeSteps', (tester) async {
    final sensors = FakeEnvSensors();
    var passed = 0;
    await tester.pumpWidget(
      host(
        sensors,
        WalkChallenge(
          args: ChallengeArgs(
            difficulty: 2,
            random: Random(1),
            onPassed: () => passed++,
            params: const {'steps': 12},
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      sensors.stepController.add(ms(i * 600));
      await tester.pump();
    }
    await tester.pump();
    expect(passed, 1);
  });

  testWidgets('walkWidget_asksForPermission', (tester) async {
    final sensors = FakeEnvSensors(permissionGranted: false);
    await tester.pumpWidget(
      host(
        sensors,
        WalkChallenge(
          args: ChallengeArgs(
            difficulty: 2,
            random: Random(1),
            onPassed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('walk-permission')), findsOneWidget);
  });

  testWidgets('walkSetup_countsSteps', (tester) async {
    final sensors = FakeEnvSensors();
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      host(
        sensors,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await setupWalk(context, const {}),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('walk-start')));
    await tester.pump();
    for (var i = 0; i < 18; i++) {
      sensors.stepController.add(ms(i * 600));
      await tester.pump();
    }
    await tester.pump();
    await tester.tap(find.byKey(const Key('setup-save')));
    await tester.pumpAndSettle();
    expect(saved, {'steps': 18});
  });
}
