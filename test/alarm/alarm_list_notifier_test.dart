import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';

void main() {
  late FakeAlarmPlatform fake;
  late ProviderContainer container;

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [alarmPlatformProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    fake = FakeAlarmPlatform();
    container = make();
  });

  AlarmListNotifier notifier() => container.read(alarmListProvider.notifier);
  Future<List<Alarm>> state() => container.read(alarmListProvider.future);

  test('build loads from platform', () async {
    fake = FakeAlarmPlatform(
      seed: [
        Alarm(id: 1, hour: 7, minute: 0),
        Alarm(id: 2, hour: 8, minute: 0),
      ],
    );
    container = make();
    expect(await state(), hasLength(2));
  });

  test('add assigns incrementing ids and calls upsert', () async {
    await state();
    final a = await notifier().add(hour: 7, minute: 0);
    final b = await notifier().add(hour: 8, minute: 0);
    expect([a.id, b.id], [1, 2]);
    expect(fake.calls, containsAllInOrder(['upsert:1', 'upsert:2']));
  });

  test('state is sorted by time', () async {
    await state();
    await notifier().add(hour: 8, minute: 0);
    await notifier().add(hour: 6, minute: 30);
    expect((await state()).map((a) => a.timeLabel), ['06:30', '08:00']);
  });

  test('setEnabled(false) upserts disabled alarm', () async {
    await state();
    await notifier().add(hour: 7, minute: 0);
    await notifier().setEnabled(1, false);
    expect(fake.stored[1]!.enabled, isFalse);
    expect((await state()).single.enabled, isFalse);
  });

  test('save replaces alarm', () async {
    await state();
    final a = await notifier().add(hour: 7, minute: 0);
    await notifier().save(a.copyWith(label: 'Gym'));
    expect((await state()).single.label, 'Gym');
  });

  test('remove deletes', () async {
    await state();
    await notifier().add(hour: 7, minute: 0);
    await notifier().remove(1);
    expect(await state(), isEmpty);
    expect(fake.calls.last, 'delete:1');
  });

  test('remove updates state before the platform answers', () async {
    await state();
    await notifier().add(hour: 7, minute: 0);
    final pending = notifier().remove(1);
    expect(container.read(alarmListProvider).value, isEmpty);
    await pending;
  });

  test('failed remove restores the alarm', () async {
    await state();
    await notifier().add(hour: 7, minute: 0);
    fake.failWith = PlatformException(code: 'x');
    await expectLater(notifier().remove(1), throwsA(isA<PlatformException>()));
    expect((await state()).single.id, 1);
  });

  group('series', () {
    const five = SeriesConfig(count: 5, everyMinutes: 5);

    Future<Alarm> addSeries() =>
        notifier().addAlarm(Alarm(id: 0, hour: 17, minute: 0, series: five));

    test('saving a main alarm creates its series', () async {
      final main = await addSeries();
      final ids = fake.stored.keys.toSet();
      expect(ids, {
        main.id,
        for (var k = 1; k < 5; k++) seriesChildId(main.id, k),
      });
      expect(fake.stored[seriesChildId(main.id, 4)]!.timeLabel, '17:20');
    });

    test('a smaller series removes the extra alarms', () async {
      final main = await addSeries();
      await notifier().save(
        main.copyWith(
          series: () => const SeriesConfig(count: 3, everyMinutes: 5),
        ),
      );
      expect(fake.stored.keys.toSet(), {
        main.id,
        seriesChildId(main.id, 1),
        seriesChildId(main.id, 2),
      });
      expect((await state()).length, 3);
    });

    test('removing the series removes its alarms', () async {
      final main = await addSeries();
      await notifier().save(main.copyWith(series: () => null));
      expect(fake.stored.keys, [main.id]);
    });

    test('deleting the main alarm deletes the series', () async {
      final main = await addSeries();
      await notifier().remove(main.id);
      expect(fake.stored, isEmpty);
      expect(await state(), isEmpty);
    });

    test('switching the main alarm off switches the series off', () async {
      final main = await addSeries();
      await notifier().setEnabled(main.id, false);
      expect(fake.stored.values.every((a) => !a.enabled), isTrue);
    });

    test('split makes independent alarms at the same times', () async {
      final main = await addSeries();
      await notifier().split(main.id);
      final all = await state();
      expect(all, hasLength(5));
      expect(all.every((a) => a.parentId == null && a.series == null), isTrue);
      expect(
        [for (final a in all) a.timeLabel],
        ['17:00', '17:05', '17:10', '17:15', '17:20'],
      );
      // A split alarm is now edited on its own.
      final child = all.last;
      await notifier().save(child.copyWith(minute: 30));
      expect(fake.stored[child.id]!.minute, 30);
      expect(fake.stored.length, 5);
    });

    test('new main alarms do not take series ids', () async {
      final main = await addSeries();
      final next = await notifier().addAlarm(Alarm(id: 0, hour: 9, minute: 0));
      expect(next.id, main.id + 1);
      expect(fake.stored.keys.where((id) => id == next.id), hasLength(1));
    });

    test('a series switched on again never overwrites split alarms', () async {
      final main = await addSeries();
      await notifier().split(main.id);
      final gym = (await state()).firstWhere(
        (a) => a.id == seriesChildId(main.id, 2),
      );
      await notifier().save(gym.copyWith(hour: 9, label: 'gym'));
      await notifier().save(
        (await state())
            .firstWhere((a) => a.id == main.id)
            .copyWith(
              series: () => const SeriesConfig(count: 3, everyMinutes: 5),
            ),
      );
      final kept = fake.stored[gym.id]!;
      expect(kept.label, 'gym');
      expect(kept.hour, 9);
      expect(kept.parentId, isNull);
      final kids = fake.stored.values.where((a) => a.parentId == main.id);
      expect([for (final k in kids) k.timeLabel]..sort(), ['17:05', '17:10']);
    });

    test('a failed delete never leaves a series half deleted', () async {
      final main = await addSeries();
      fake.failOn = (c) => c == 'delete:${seriesChildId(main.id, 2)}';
      await expectLater(notifier().remove(main.id), throwsA(anything));
      // Whatever is left natively is what the list shows, and the main
      // alarm is still there to own it.
      expect({for (final a in await state()) a.id}, fake.stored.keys.toSet());
      expect(fake.stored.containsKey(main.id), isTrue);
    });

    test('a failed save restores the series as it was', () async {
      final main = await addSeries();
      final before = Map.of(fake.stored);
      fake.failOn = (c) => c == 'upsert:${seriesChildId(main.id, 3)}';
      await expectLater(
        notifier().save(main.copyWith(hour: 8)),
        throwsA(anything),
      );
      expect(fake.stored, before);
      expect({for (final a in await state()) a.id: a}, before);
    });

    test('series ids never get too large for the phone', () async {
      // Repeated split → series → split would multiply ids by 100 each time.
      var main = await notifier().addAlarm(Alarm(id: 0, hour: 6, minute: 0));
      for (var round = 0; round < 5; round++) {
        await notifier().save(
          main.copyWith(
            series: () => const SeriesConfig(count: 2, everyMinutes: 1),
          ),
        );
        await notifier().split(main.id);
        final all = await state();
        main = all.reduce((a, b) => a.id > b.id ? a : b);
      }
      expect(fake.stored.keys.every((id) => id < maxAlarmId), isTrue);
    });
  });
}
