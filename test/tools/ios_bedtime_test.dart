import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:byebyesleep/tools/bedtime.dart';
import 'package:byebyesleep/tools/ios_bedtime.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';

const daily = {1, 2, 3, 4, 5, 6, 7};
const eightHours = 8 * 60;

Alarm alarm(
  int hour,
  int minute,
  Set<int> days, {
  int id = 1,
  bool enabled = true,
  DateTime? onceAt,
}) => Alarm(
  id: id,
  hour: hour,
  minute: minute,
  repeatDays: days,
  enabled: enabled,
  onceAt: onceAt,
);

class FakeNotifier implements LocalNotifier {
  final calls = <String>[];
  final scheduled = <String, (DateTime, String, String)>{};

  @override
  Future<void> schedule(
    String id,
    DateTime at,
    String title,
    String body,
  ) async {
    calls.add('schedule:$id');
    scheduled[id] = (at, title, body);
  }

  @override
  Future<void> cancelPrefix(String prefix) async {
    calls.add('cancelPrefix:$prefix');
    scheduled.removeWhere((id, _) => id.startsWith(prefix));
  }
}

class MemoryBedtimeStore implements BedtimeStore {
  BedtimeSettings? saved;

  @override
  Future<BedtimeSettings?> load() async => saved;

  @override
  Future<void> save(BedtimeSettings settings) async => saved = settings;
}

void main() {
  // Port of android/.../alarm/BedtimeTest.kt. 2026-10-12 is a Monday.
  group('nextBedtime', () {
    test('bedtime is the alarm minus the sleep goal', () {
      final b = nextBedtime(
        [alarm(7, 0, daily)],
        DateTime(2026, 10, 12, 20),
        eightHours,
      )!;
      expect(b.at, DateTime(2026, 10, 12, 23));
      expect(b.alarm, DateTime(2026, 10, 13, 7));
    });

    test('past bedtime reminds for the following night', () {
      final b = nextBedtime(
        [alarm(7, 0, daily)],
        DateTime(2026, 10, 12, 23, 30),
        eightHours,
      )!;
      expect(b.at, DateTime(2026, 10, 13, 23));
    });

    test('a series uses its first ring', () {
      final alarms = [alarm(6, 30, daily), alarm(6, 40, daily, id: 2)];
      // 22:35: bedtime for 06:30 passed; 06:40 must not give a 22:40 one.
      expect(
        nextBedtime(alarms, DateTime(2026, 10, 12, 22, 35), eightHours)!.at,
        DateTime(2026, 10, 13, 22, 30),
      );
      expect(
        nextBedtime(alarms, DateTime(2026, 10, 12, 21), eightHours)!.at,
        DateTime(2026, 10, 12, 22, 30),
      );
    });

    test('only alarms that are on', () {
      expect(
        nextBedtime(
          [alarm(7, 0, daily, enabled: false)],
          DateTime(2026, 10, 12, 20),
          eightHours,
        ),
        isNull,
      );
      expect(nextBedtime([], DateTime(2026, 10, 12, 20), eightHours), isNull);
    });

    test('weekend without alarm waits for the next one', () {
      // Mon–Fri 07:00; Friday 23:30 → alarm Monday, bedtime Sunday 23:00.
      final b = nextBedtime(
        [
          alarm(7, 0, {1, 2, 3, 4, 5}),
        ],
        DateTime(2026, 10, 16, 23, 30),
        eightHours,
      )!;
      expect(b.at, DateTime(2026, 10, 18, 23));
    });

    test('a one-shot series alarm rings at its own date', () {
      final b = nextBedtime(
        [alarm(9, 0, const {}, onceAt: DateTime(2026, 10, 15, 9))],
        DateTime(2026, 10, 12, 20),
        eightHours,
      )!;
      expect(b.alarm, DateTime(2026, 10, 15, 9));
      expect(b.at, DateTime(2026, 10, 15, 1));
      expect(
        nextBedtime(
          [alarm(9, 0, const {}, onceAt: DateTime(2026, 10, 12, 9))],
          DateTime(2026, 10, 12, 20),
          eightHours,
        ),
        isNull,
      );
    });

    test('text says when the alarm rings', () {
      expect(
        bedtimeText(DateTime(2026, 10, 13, 7), eightHours),
        'Your alarm rings at 07:00 — go to bed now for 8 h of sleep.',
      );
      expect(
        bedtimeText(DateTime(2026, 10, 13, 6, 30), 450),
        'Your alarm rings at 06:30 — go to bed now for 7 h 30 min of sleep.',
      );
    });
  });

  group('planBedtimes', () {
    test('the next 7 nights, one per morning', () {
      final plan = planBedtimes(
        [alarm(6, 30, daily), alarm(6, 40, daily, id: 2)],
        DateTime(2026, 10, 12, 20),
        eightHours,
      );
      expect(plan.map((r) => r.at), [
        for (var d = 0; d < 7; d++) DateTime(2026, 10, 12 + d, 22, 30),
      ]);
    });

    test('weekdays only skip the nights before a free day', () {
      final plan = planBedtimes(
        [
          alarm(7, 0, {1, 2, 3, 4, 5}),
        ],
        DateTime(2026, 10, 12, 20),
        eightHours,
      );
      expect(plan.map((r) => r.at), [
        DateTime(2026, 10, 12, 23), // Mon night → Tue
        DateTime(2026, 10, 13, 23),
        DateTime(2026, 10, 14, 23),
        DateTime(2026, 10, 15, 23), // Thu night → Fri
        DateTime(2026, 10, 18, 23), // Sun night → Mon
        DateTime(2026, 10, 19, 23),
        DateTime(2026, 10, 20, 23),
      ]);
    });

    test('nothing without alarms', () {
      expect(planBedtimes([], DateTime(2026, 10, 12, 20), eightHours), isEmpty);
    });
  });

  group('IosBedtime', () {
    late FakeNotifier notifier;
    late MemoryBedtimeStore store;
    late List<Alarm> alarms;
    IosBedtime make() => IosBedtime(
      store: store,
      notifier: notifier,
      alarms: () async => alarms,
      now: () => DateTime(2026, 10, 12, 20),
    );

    setUp(() {
      notifier = FakeNotifier();
      store = MemoryBedtimeStore();
      alarms = [alarm(6, 30, daily)];
    });

    test('off by default, with an 8 h goal', () async {
      final s = (await make().get())!;
      expect(s.enabled, isFalse);
      expect(s.sleepMinutes, 480);
      expect(s.nextAt, isNull);
    });

    test('turning it on schedules the next 7 reminders', () async {
      final s = await make().set(const BedtimeSettings(enabled: true));
      expect(s.nextAt, DateTime(2026, 10, 12, 22, 30));
      expect(notifier.calls.first, 'cancelPrefix:bedtime-');
      expect(notifier.scheduled, hasLength(7));
      final (at, title, body) = notifier.scheduled.values.first;
      expect(at, DateTime(2026, 10, 12, 22, 30));
      expect(title, 'Time for bed');
      expect(
        body,
        'Your alarm rings at 06:30 — go to bed now for 8 h of sleep.',
      );
      expect(store.saved?.enabled, isTrue);
      expect((await make().get())!.nextAt, DateTime(2026, 10, 12, 22, 30));
    });

    test('a new goal moves the reminders', () async {
      final b = make();
      await b.set(const BedtimeSettings(enabled: true));
      final s = await b.set(
        const BedtimeSettings(enabled: true, sleepMinutes: 450),
      );
      expect(s.nextAt, DateTime(2026, 10, 12, 23));
      expect(notifier.scheduled, hasLength(7));
      expect(notifier.scheduled.values.first.$1, DateTime(2026, 10, 12, 23));
    });

    test('turning it off cancels them', () async {
      final b = make();
      await b.set(const BedtimeSettings(enabled: true));
      notifier.calls.clear();
      final s = await b.set(const BedtimeSettings());
      expect(s.nextAt, isNull);
      expect(notifier.calls, ['cancelPrefix:bedtime-']);
      expect(notifier.scheduled, isEmpty);
    });

    test('re-plans only when the plan changed', () async {
      final b = make();
      await b.set(const BedtimeSettings(enabled: true));
      notifier.calls.clear();
      expect(await b.replan(alarms), isFalse);
      expect(notifier.calls, isEmpty);
      alarms = [alarm(7, 0, daily)];
      expect(await b.replan(alarms), isTrue);
      expect(notifier.scheduled.values.first.$1, DateTime(2026, 10, 12, 23));
    });
  });

  group('providers', () {
    test('iPhone gets IosBedtime, Android the native channel', () {
      final ios = ProviderContainer(
        overrides: [isIosProvider.overrideWithValue(true)],
      );
      addTearDown(ios.dispose);
      expect(ios.read(bedtimePlatformProvider), isA<IosBedtime>());
      final android = ProviderContainer(
        overrides: [isIosProvider.overrideWithValue(false)],
      );
      addTearDown(android.dispose);
      expect(
        android.read(bedtimePlatformProvider),
        isA<MethodChannelBedtime>(),
      );
    });

    test('on iPhone, a change to the alarms re-plans the reminders', () async {
      final notifier = FakeNotifier();
      final store = MemoryBedtimeStore()
        ..saved = const BedtimeSettings(enabled: true);
      final platform = FakeAlarmPlatform(seed: [alarm(6, 30, daily)]);
      final c = ProviderContainer(
        overrides: [
          isIosProvider.overrideWithValue(true),
          localNotifierProvider.overrideWithValue(notifier),
          bedtimeStoreProvider.overrideWithValue(store),
          alarmPlatformProvider.overrideWithValue(platform),
          nowProvider.overrideWithValue(() => DateTime(2026, 10, 12, 20)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(iosBedtimeSyncProvider, (_, _) {});
      await c.read(alarmListProvider.future);
      await pumpEventQueue();
      expect(
        notifier.scheduled.values.first.$1,
        DateTime(2026, 10, 12, 22, 30),
      );
      await c.read(alarmListProvider.notifier).save(alarm(7, 0, daily));
      await pumpEventQueue();
      expect(notifier.scheduled.values.first.$1, DateTime(2026, 10, 12, 23));
      expect(notifier.scheduled, hasLength(7));
    });

    test('elsewhere the sync does nothing', () async {
      final notifier = FakeNotifier();
      final c = ProviderContainer(
        overrides: [
          isIosProvider.overrideWithValue(false),
          localNotifierProvider.overrideWithValue(notifier),
          alarmPlatformProvider.overrideWithValue(FakeAlarmPlatform()),
        ],
      );
      addTearDown(c.dispose);
      c.listen(iosBedtimeSyncProvider, (_, _) {});
      await pumpEventQueue();
      expect(notifier.calls, isEmpty);
    });
  });
}
