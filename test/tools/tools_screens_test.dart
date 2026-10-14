import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:byebyesleep/tools/clock_screen.dart';
import 'package:byebyesleep/tools/stopwatch_screen.dart';
import 'package:byebyesleep/tools/timer_bell.dart';
import 'package:byebyesleep/tools/timer_screen.dart';
import 'package:byebyesleep/tools/timer_state.dart';
import 'package:byebyesleep/tools/world_clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/memory_timer_store.dart';

class FakeBell implements TimerBell {
  final calls = <String>[];

  @override
  Future<void> schedule(int id, DateTime at, String label) async =>
      calls.add('schedule:$id:${at.millisecondsSinceEpoch}');

  @override
  Future<void> cancel(int id) async => calls.add('cancel:$id');
}

class FakeZones implements ZoneOffsets {
  @override
  Future<Map<String, Duration>> offsets(
    List<String> zones,
    DateTime at,
  ) async => {
    for (final z in zones)
      if (z == 'Asia/Tokyo') z: const Duration(hours: 9),
  };
}

class MemoryWorldStore implements WorldClockStore {
  List<String> saved = [];

  @override
  Future<List<String>> load() async => saved;

  @override
  Future<void> save(List<String> zones) async => saved = zones;
}

void main() {
  late DateTime now;
  late FakeBell bell;
  late MemoryTimerStore store;
  late MemoryWorldStore world;

  setUp(() {
    now = DateTime(2026, 10, 14, 6, 30, 5);
    bell = FakeBell();
    store = MemoryTimerStore();
    world = MemoryWorldStore();
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
          zoneOffsetsProvider.overrideWithValue(FakeZones()),
          worldClockStoreProvider.overrideWithValue(world),
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

  testWidgets('world clocks: add a city, see its time, remove it', (
    tester,
  ) async {
    await pump(tester, const ClockScreen());
    await tester.pump();
    await tester.tap(find.byKey(const Key('world-add')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const Key('world-search')), 'tok');
    await tester.pump();
    await tester.tap(find.byKey(const Key('city-Asia/Tokyo')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(world.saved, ['Asia/Tokyo']);
    expect(find.text('Tokyo'), findsOneWidget);
    // 06:30 here (UTC in tests) is 15:30 in Tokyo.
    expect(find.text('15:30'), findsOneWidget);
    expect(find.textContaining('+9 h'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('world-Asia/Tokyo')),
      const Offset(-600, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(world.saved, isEmpty);
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

  testWidgets('timers: start one from a preset; pause cancels its bell', (
    tester,
  ) async {
    await pump(tester, const TimerScreen());
    await tester.tap(find.byKey(const Key('timer-preset-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-add')));
    await tester.pump();
    expect(
      bell.calls.last,
      'schedule:1:${now.add(const Duration(minutes: 5)).millisecondsSinceEpoch}',
    );
    await later(tester, const Duration(seconds: 61));
    expect(find.text('03:59'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-1-toggle'))); // pause
    await tester.pump();
    expect(bell.calls.last, 'cancel:1');
    expect(store.saved!.timers.single.state.running, isFalse);
  });

  testWidgets('timers: several run at once, each with its own bell', (
    tester,
  ) async {
    await pump(tester, const TimerScreen());
    await tester.tap(find.byKey(const Key('timer-preset-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-add')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-preset-10')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('timer-add')));
    await tester.pump();
    expect(bell.calls.where((c) => c.startsWith('schedule')), hasLength(2));
    await later(tester, const Duration(seconds: 61));
    await tester.pump();
    // The 1-minute timer is up, the 10-minute one keeps going.
    expect(find.text("Time's up"), findsOneWidget);
    expect(find.text('08:59'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-1-stop')));
    await tester.pump();
    expect(bell.calls.last, 'cancel:1');
    expect(find.text("Time's up"), findsNothing);
    expect(store.saved!.timers.map((t) => t.id), [2]);
  });

  testWidgets('timers: a running timer continues after the app restarts', (
    tester,
  ) async {
    store.saved = TimersState(
      timers: [
        TimerEntry(
          id: 4,
          state: TimerState(
            total: const Duration(minutes: 10),
            endsAt: now.add(const Duration(minutes: 3)),
          ),
        ),
      ],
      nextId: 5,
    );
    await pump(tester, const TimerScreen());
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-4-delete')));
    await tester.pump();
    expect(bell.calls.last, 'cancel:4');
    expect(store.saved!.timers, isEmpty);
  });
}
