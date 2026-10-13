import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/app/routes.dart';
import 'package:byebyesleep/ringing/ring_screen.dart';
import 'package:byebyesleep/watch_setup/watch_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_watch_store.dart';
import '../support/fake_alarm_platform.dart';
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';

void main() {
  late FakeAlarmPlatform fake;
  late int finished;

  Future<void> pumpRing(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSettingsStoreProvider.overrideWithValue(MemoryWatchStore()),
          alarmPlatformProvider.overrideWithValue(fake),
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          home: RingScreen(alarmId: 7, onFinished: () => finished++),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  setUp(() {
    fake = FakeAlarmPlatform(
      // No stages: Stop/Snooze are available straight away.
      seed: [
        Alarm(id: 7, hour: 6, minute: 30, label: 'Work', stages: const []),
      ],
    );
    finished = 0;
  });

  testWidgets('showsAlarmLabel', (tester) async {
    await pumpRing(tester);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('stopCallsPlatformAndFinishes', (tester) async {
    await pumpRing(tester);
    await tester.tap(find.byKey(const Key('stop')));
    await tester.pump();
    expect(fake.calls, contains('stopRinging'));
    expect(finished, 1);
  });

  testWidgets('snoozeUses9Minutes', (tester) async {
    await pumpRing(tester);
    await tester.tap(find.byKey(const Key('snooze')));
    await tester.pump();
    expect(fake.calls, containsAllInOrder(['snooze:7:9', 'stopRinging']));
    expect(finished, 1);
  });

  testWidgets('snoozeFailureKeepsRingingAndShowsError', (tester) async {
    await pumpRing(tester);
    fake.failWith = PlatformException(code: 'x');
    await tester.tap(find.byKey(const Key('snooze')));
    await tester.pump();
    expect(fake.calls, isNot(contains('stopRinging')));
    expect(finished, 0);
    expect(
      find.text('Snooze failed — the alarm keeps ringing.'),
      findsOneWidget,
    );
  });

  testWidgets('ringScreen_backDoesNotPop', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSettingsStoreProvider.overrideWithValue(MemoryWatchStore()),
          alarmPlatformProvider.overrideWithValue(fake),
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RingScreen(alarmId: 7, onFinished: () {}),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(RingScreen), findsOneWidget);
  });

  testWidgets('ringRouteBuildsRingScreenForId', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchSettingsStoreProvider.overrideWithValue(MemoryWatchStore()),
          alarmPlatformProvider.overrideWithValue(fake),
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
        ],
        child: MaterialApp(
          onGenerateRoute: generateRoute,
          onGenerateInitialRoutes: (name) => [
            generateRoute(RouteSettings(name: name)),
          ],
          initialRoute: '/ring/7',
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byWidgetPredicate((w) => w is RingScreen && w.alarmId == 7),
      findsOneWidget,
    );
  });
}
