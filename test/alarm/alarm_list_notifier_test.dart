import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
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
}
