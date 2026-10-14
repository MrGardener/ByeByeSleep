import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:byebyesleep/tools/clock_screen.dart';
import 'package:byebyesleep/tools/stopwatch_screen.dart';
import 'package:byebyesleep/tools/timer_bell.dart';
import 'package:byebyesleep/tools/timer_screen.dart';
import 'package:byebyesleep/tools/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/memory_timer_store.dart';

class FakeBell implements TimerBell {
  final calls = <String>[];

  @override
  Future<void> schedule(DateTime at, String label) async =>
      calls.add('schedule:${at.millisecondsSinceEpoch}');

  @override
  Future<void> cancel() async => calls.add('cancel');
}

void main() {
  late DateTime now;
  late FakeBell bell;
  late MemoryTimerStore store;

  setUp(() {
    now = DateTime(2026, 10, 14, 6, 30, 5);
    bell = FakeBell();
    store = MemoryTimerStore();
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    FakeAlarmPlatform? alarms,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowProvider.overrideWithValue(() => now),
          timerBellProvider.overrideWithValue(bell),
          timerStoreProvider.overrideWithValue(store),
          alarmPlatformProvider.overrideWithValue(
            alarms ?? FakeAlarmPlatform(),
          ),
        ],
        child: MaterialApp(home: Scaffold(body: screen)),
      ),
    );
    await tester.pump();
  }

  Future<void> later(WidgetTester tester, Duration d) async {
    now = now.add(d);
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('clock shows the time, the date and the next alarm', (
    tester,
  ) async {
    await pump(
      tester,
      const ClockScreen(),
      alarms: FakeAlarmPlatform(seed: [Alarm(id: 1, hour: 7, minute: 15)]),
    );
    await tester.pump();
    expect(find.text('06:30'), findsOneWidget);
    expect(find.textContaining('Wednesday'), findsOneWidget);
    expect(find.textContaining('Next alarm 07:15'), findsOneWidget);
    expect(find.textContaining('in 44 min'), findsOneWidget);
    await later(tester, const Duration(minutes: 1));
    expect(find.text('06:31'), findsOneWidget);
  });

  testWidgets('clock without alarms says so', (tester) async {
    await pump(tester, const ClockScreen());
    await tester.pump();
    expect(find.textContaining('No alarm set'), findsOneWidget);
  });

  testWidgets('stopwatch: start, lap, pause, reset', (tester) async {
    await pump(tester, const StopwatchScreen());
    expect(find.text('00:00.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sw-start')));
    await later(tester, const Duration(seconds: 2));
    expect(find.text('00:02.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sw-lap')));
    await later(tester, const Duration(seconds: 1));
    expect(find.text('Lap 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sw-start'))); // pause
    await later(tester, const Duration(seconds: 5));
    expect(find.text('00:03.00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sw-reset')));
    await tester.pump();
    expect(find.text('00:00.00'), findsOneWidget);
    expect(find.text('Lap 1'), findsNothing);
  });

  testWidgets('timer: a preset, start rings natively, pause cancels', (
    tester,
  ) async {
    await pump(tester, const TimerScreen());
    await tester.tap(find.byKey(const Key('timer-preset-5')));
    await tester.pump();
    expect(find.text('05:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-start')));
    await tester.pump();
    expect(
      bell.calls.last,
      'schedule:${now.add(const Duration(minutes: 5)).millisecondsSinceEpoch}',
    );
    await later(tester, const Duration(seconds: 61));
    expect(find.text('03:59'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-start'))); // pause
    await tester.pump();
    expect(bell.calls.last, 'cancel');
    expect(store.saved!.running, isFalse);
  });

  testWidgets("timer: when time is up it says so and Stop silences it", (
    tester,
  ) async {
    await pump(tester, const TimerScreen());
    await tester.tap(find.byKey(const Key('timer-preset-1')));
    await tester.tap(find.byKey(const Key('timer-start')));
    await later(tester, const Duration(seconds: 61));
    await tester.pump();
    expect(find.text("Time's up"), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-stop')));
    await tester.pump();
    expect(bell.calls.last, 'cancel');
    expect(find.text('01:00'), findsOneWidget);
  });

  testWidgets('timer: a running timer continues after the app restarts', (
    tester,
  ) async {
    store.saved = TimerState(
      total: const Duration(minutes: 10),
      endsAt: now.add(const Duration(minutes: 3)),
    );
    await pump(tester, const TimerScreen());
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);
  });
}
