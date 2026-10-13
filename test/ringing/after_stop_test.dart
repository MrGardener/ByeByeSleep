import 'dart:math';
import 'dart:typed_data';

import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:byebyesleep/challenges/core/camera.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/app/routes.dart';
import 'package:byebyesleep/ringing/emergency.dart';
import 'package:byebyesleep/ringing/ring_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../challenges/photo_match_test.dart' show MemoryPhotoStore;
import '../support/challenge_solvers.dart';
import '../support/fake_alarm_platform.dart';
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';
import 'emergency_test.dart' show FakeEmergencySource;

void main() {
  late FakeAlarmPlatform fake;
  late MemoryPhotoStore photos;
  late int finished;
  var now = DateTime(2026, 10, 13, 17, 5);

  Future<void> ring(WidgetTester tester, int id) async {
    await tester.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmPlatformProvider.overrideWithValue(fake),
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
          emergencySourceProvider.overrideWithValue(FakeEmergencySource()),
          photoStoreProvider.overrideWithValue(photos),
        ],
        child: MaterialApp(
          onGenerateRoute: generateRoute,
          home: RingScreen(
            alarmId: id,
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

  setUp(() {
    photos = MemoryPhotoStore();
    finished = 0;
    now = DateTime(2026, 10, 13, 17, 5);
  });

  testWidgets('reminder-only alarm: Stop at once, then the reminder', (
    tester,
  ) async {
    final path = await photos.save(Uint8List.fromList([1, 2, 3]));
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(
          id: 3,
          hour: 17,
          minute: 5,
          stages: const [],
          reminder: Reminder(photoPath: path, caption: 'Take the keys'),
        ),
      ],
    );
    await ring(tester, 3);
    expect(find.byKey(const Key('stop')), findsOneWidget);
    expect(find.byKey(const Key('ring-reminder')), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('stopRinging'));
    expect(find.byKey(const Key('reminder-screen')), findsOneWidget);
    expect(find.text('Take the keys'), findsWidgets);
    expect(finished, 0);
    await tester.tap(find.byKey(const Key('reminder-done')));
    await tester.pumpAndSettle();
    expect(finished, 1);
  });

  testWidgets('a new alarm ringing replaces the reminder screen', (
    tester,
  ) async {
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(
          id: 3,
          hour: 17,
          minute: 5,
          stages: const [],
          reminder: const Reminder(caption: 'Take the keys'),
        ),
        Alarm(id: 5, hour: 17, minute: 6, stages: const []),
      ],
    );
    await ring(tester, 3);
    await tester.tap(find.byKey(const Key('stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-screen')), findsOneWidget);
    fake.ringing = [5];
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-screen')), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is RingScreen && w.alarmId == 5),
      findsOneWidget,
    );
    expect(finished, 0); // the activity stays for the new ring
  });

  group('awake check', () {
    testWidgets('Stop schedules the check when the alarm has one', (
      tester,
    ) async {
      fake = FakeAlarmPlatform(
        seed: [
          Alarm(
            id: 3,
            hour: 17,
            minute: 5,
            stages: const [],
            followUpMinutes: 10,
          ),
        ],
      );
      await ring(tester, 3);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      expect(fake.calls, contains('followUp:3:10'));
      expect(finished, 1);
    });

    testWidgets('no check unless set', (tester) async {
      fake = FakeAlarmPlatform(
        seed: [Alarm(id: 3, hour: 17, minute: 5, stages: const [])],
      );
      await ring(tester, 3);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      expect(fake.calls.where((c) => c.startsWith('followUp')), isEmpty);
    });

    testWidgets('the check ring asks one quick challenge and does not loop', (
      tester,
    ) async {
      fake =
          FakeAlarmPlatform(
              seed: [Alarm(id: 3, hour: 17, minute: 5, followUpMinutes: 10)],
            )
            ..ringProgress = RingProgress(
              alarmId: 3,
              stageIndex: 0,
              startedAtMs: now.millisecondsSinceEpoch,
              followUp: true,
            );
      await ring(tester, 3);
      expect(find.text('Still awake?'), findsOneWidget);
      expect(find.text('Stage 1 of 1'), findsOneWidget);
      expect(find.byKey(const Key('stroop-word')), findsOneWidget);
      await solveStroop(tester);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      expect(fake.calls.where((c) => c.startsWith('followUp')), isEmpty);
      expect(finished, 1);
    });
  });

  group('series', () {
    final main = Alarm(
      id: 4,
      hour: 17,
      minute: 0,
      stages: const [],
      series: const SeriesConfig(count: 4, everyMinutes: 5),
    );

    setUp(() {
      // 17:00 main, 17:05 (401, ringing now), 17:10 (402), 17:15 (403).
      fake = FakeAlarmPlatform(seed: [main, ...seriesChildren(main)]);
    });

    testWidgets('after Stop, skipping skips only the later alarms', (
      tester,
    ) async {
      await ring(tester, 401);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('skip-series-dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('skip-series-yes')));
      await tester.pumpAndSettle();
      expect(fake.calls.where((c) => c.startsWith('skipNext')), [
        'skipNext:402',
        'skipNext:403',
      ]);
      expect(finished, 1);
    });

    testWidgets('keeping the series skips nothing', (tester) async {
      await ring(tester, 401);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('skip-series-no')));
      await tester.pumpAndSettle();
      expect(fake.calls.where((c) => c.startsWith('skipNext')), isEmpty);
      expect(finished, 1);
    });

    testWidgets('the last alarm of a series does not ask', (tester) async {
      now = DateTime(2026, 10, 13, 17, 15);
      await ring(tester, 403);
      await tester.tap(find.byKey(const Key('stop')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('skip-series-dialog')), findsNothing);
      expect(finished, 1);
    });
  });
}
