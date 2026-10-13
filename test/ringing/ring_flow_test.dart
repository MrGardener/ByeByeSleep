import 'dart:math';

import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/battery.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/ringing/ring_screen.dart';
import 'package:byebyesleep/ringing/emergency.dart';
import 'package:byebyesleep/ringing/safety_exit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'emergency_test.dart' show FakeEmergencySource;
import '../support/challenge_solvers.dart';
import '../support/fake_alarm_platform.dart';
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';

/// Battery that cannot be read (broken plugin, odd device).
class BrokenCharge implements ChargeSource {
  @override
  Future<bool> isPlugged() async => throw StateError('no battery info');

  @override
  Stream<bool> get plugged => const Stream.empty();
}

void main() {
  late FakeAlarmPlatform fake;
  late DateTime now;
  late int finished;
  late FakeEmergencySource emergency;

  Future<void> pumpRing(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmPlatformProvider.overrideWithValue(fake),
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
          chargeSourceProvider.overrideWithValue(BrokenCharge()),
          emergencySourceProvider.overrideWithValue(emergency),
        ],
        child: MaterialApp(
          home: RingScreen(
            alarmId: 7,
            onFinished: () => finished++,
            clock: () => now,
            random: Random(1),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  /// Moves the fake clock and lets the ring screen's 1 s ticker run.
  Future<void> advance(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() {
    emergency = FakeEmergencySource();
    now = DateTime(2026, 10, 12, 7);
    finished = 0;
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(
          id: 7,
          hour: 7,
          minute: 0,
          stages: const [
            StageConfig(ChallengeId.brokenCalculator, difficulty: 1),
            StageConfig(ChallengeId.stroopTap, difficulty: 1),
          ],
          pauseSeconds: 20,
        ),
      ],
    );
  });

  testWidgets('ringFlow_buttonsHiddenUntilDone', (tester) async {
    await pumpRing(tester);
    expect(find.byKey(const Key('stop')), findsNothing);
    expect(find.byKey(const Key('snooze')), findsNothing);
    expect(find.text('Stage 1 of 2'), findsOneWidget);
    expect(fake.calls, contains('saveRingProgress:7:0'));
  });

  testWidgets('ringFlow_completingStagesShowsStopAndSnooze', (tester) async {
    await pumpRing(tester);
    await solveCalculator(tester);
    expect(find.byKey(const Key('breather')), findsOneWidget);
    expect(fake.calls, contains('setRingLevel:0.2'));
    expect(fake.calls, contains('saveRingProgress:7:1'));
    await advance(tester, const Duration(seconds: 20));
    expect(fake.calls.last, 'setRingLevel:1.0');
    await solveStroop(tester);
    expect(find.byKey(const Key('stop')), findsOneWidget);
    expect(find.byKey(const Key('snooze')), findsOneWidget);
    expect(fake.calls, contains('saveRingProgress:7:2'));
  });

  testWidgets('ringFlow_withoutPause_nextStageStartsAtOnce', (tester) async {
    fake.stored[7] = fake.stored[7]!.copyWith(pauseSeconds: 0);
    await pumpRing(tester);
    await solveCalculator(tester);
    expect(find.byKey(const Key('breather')), findsNothing);
    expect(fake.calls, isNot(contains('setRingLevel:0.2')));
    expect(find.text('Stage 2 of 2'), findsOneWidget);
  });

  testWidgets('ringFlow_emergencyProtocolStopsAtAnyTime', (tester) async {
    await pumpRing(tester);
    expect(find.byKey(const Key('stop')), findsNothing);
    await tester.tap(find.byKey(const Key('emergency')));
    await tester.pumpAndSettle();
    emergency.presses.add(null);
    emergency.state = const RadioState(
      wifiOn: false,
      bluetoothOn: false,
      airplaneOn: true,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.tap(find.byKey(const Key('emergency-stop')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('stopRinging'));
    expect(finished, 1);
  });

  testWidgets('ringFlow_resumesAtSavedStage', (tester) async {
    fake.ringProgress = RingProgress(
      alarmId: 7,
      stageIndex: 1,
      startedAtMs: now.millisecondsSinceEpoch,
    );
    await pumpRing(tester);
    expect(find.text('Stage 2 of 2'), findsOneWidget);
    expect(find.byKey(const Key('stroop-word')), findsOneWidget);
  });

  testWidgets('progress of another alarm is ignored', (tester) async {
    fake.ringProgress = const RingProgress(
      alarmId: 99,
      stageIndex: 1,
      startedAtMs: 0,
    );
    await pumpRing(tester);
    expect(find.text('Stage 1 of 2'), findsOneWidget);
  });

  testWidgets('ringFlow_safetyExitAfter15Minutes', (tester) async {
    await pumpRing(tester);
    await advance(tester, const Duration(minutes: 14, seconds: 58));
    expect(find.byKey(const Key('safety-exit')), findsNothing);
    await advance(tester, const Duration(seconds: 2));
    expect(find.byKey(const Key('safety-exit')), findsOneWidget);
    await tester.tap(find.byKey(const Key('safety-exit')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const Key('safety-text')),
      'let me sleep',
    );
    await tester.tap(find.byKey(const Key('safety-confirm')));
    await tester.pump();
    expect(fake.calls, isNot(contains('stopRinging')));
    await tester.enterText(
      find.byKey(const Key('safety-text')),
      safetyParagraph,
    );
    await tester.tap(find.byKey(const Key('safety-confirm')));
    await tester.pump();
    await tester.pump();
    expect(fake.calls, contains('stopRinging'));
    expect(fake.calls.where((c) => c.startsWith('snooze')), isEmpty);
    expect(finished, 1);
  });

  testWidgets('ringFlow_fallbackAfter5Minutes', (tester) async {
    await pumpRing(tester);
    expect(find.byKey(const Key('fallback')), findsNothing);
    await advance(tester, const Duration(minutes: 2));
    expect(find.byKey(const Key('hint')), findsOneWidget);
    await advance(tester, const Duration(minutes: 3));
    await tester.tap(find.byKey(const Key('fallback')));
    await tester.pump();
    expect(find.byKey(const Key('calc-problem')), findsNothing);
    expect(find.byKey(const Key('stroop-word')), findsOneWidget);
  });

  testWidgets('missing alarm record still runs the default stages', (
    tester,
  ) async {
    fake = FakeAlarmPlatform();
    await pumpRing(tester);
    expect(find.text('Stage 1 of ${defaultStages.length}'), findsOneWidget);
  });

  testWidgets('load failure still runs the default stages', (tester) async {
    fake.readFailWith = PlatformException(code: 'broken');
    await pumpRing(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Stage 1 of ${defaultStages.length}'), findsOneWidget);
    await advance(tester, const Duration(minutes: 15));
    expect(find.byKey(const Key('safety-exit')), findsOneWidget);
  });

  testWidgets('light and battery stages are not substituted', (tester) async {
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(
          id: 7,
          hour: 7,
          minute: 0,
          stages: const [StageConfig(ChallengeId.lightsOn)],
        ),
      ],
    );
    await pumpRing(tester);
    expect(find.text('Turn on the light'), findsOneWidget);
  });

  testWidgets('a challenge that cannot run is replaced at once', (
    tester,
  ) async {
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(
          id: 7,
          hour: 7,
          minute: 0,
          stages: const [StageConfig(ChallengeId.charger, difficulty: 1)],
        ),
      ],
    );
    await pumpRing(tester);
    await tester.pump();
    expect(find.byKey(const Key('calc-problem')), findsOneWidget);
  });
}
