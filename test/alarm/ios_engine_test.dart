import 'dart:io';

import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:byebyesleep/alarm/ios/ios_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeKit implements IosAlarmKit {
  String auth = 'authorized';
  List<IosRing> rings = [];
  var syncs = 0;
  Object? failSync;
  var requested = 0;
  var settingsOpened = 0;

  @override
  Future<String> authorization() async => auth;

  @override
  Future<String> requestAuthorization() async {
    requested++;
    return auth = 'authorized';
  }

  @override
  Future<void> sync(List<IosRing> rings) async {
    syncs++;
    if (failSync case final e?) throw e;
    this.rings = rings;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

class MemoryState implements IosStateStore {
  Map<String, Object?>? saved;

  @override
  Future<Map<String, Object?>?> load() async => saved;

  @override
  Future<void> save(Map<String, Object?> state) async => saved = state;
}

void main() {
  late FakeKit kit;
  late MemoryState store;
  late DateTime now;
  IosAlarmEngine engine() =>
      IosAlarmEngine(kit: kit, store: store, now: () => now);

  setUp(() {
    kit = FakeKit();
    store = MemoryState();
    now = DateTime(2026, 10, 13, 6); // Tuesday 06:00
  });

  List<DateTime> times(Iterable<IosRing> rings) => [
    for (final r in rings) DateTime.fromMillisecondsSinceEpoch(r.atMs),
  ];

  test('nextRing: later today, tomorrow, or the next allowed weekday', () {
    final a = Alarm(id: 1, hour: 7, minute: 30);
    expect(nextRing(a, now), DateTime(2026, 10, 13, 7, 30));
    expect(
      nextRing(a, DateTime(2026, 10, 13, 8)),
      DateTime(2026, 10, 14, 7, 30),
    );
    final mondays = Alarm(id: 1, hour: 7, minute: 30, repeatDays: {1});
    expect(nextRing(mondays, now), DateTime(2026, 10, 19, 7, 30));
  });

  test(
    'upsert schedules the alarm, its backup chain and the next day',
    () async {
      final e = engine();
      final at = await e.upsert(
        Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1, 2, 3, 4, 5, 6, 7}),
      );
      expect(at, DateTime(2026, 10, 13, 7).millisecondsSinceEpoch);
      final main = kit.rings.where((r) => !r.backup);
      // A week of rings is armed, in case the app is not opened.
      expect(times(main), [
        for (var d = 13; d <= 19; d++) DateTime(2026, 10, d, 7),
      ]);
      final todayChain = times(
        kit.rings.where(
          (r) =>
              r.backup &&
              r.atMs < DateTime(2026, 10, 14).millisecondsSinceEpoch,
        ),
      );
      // Default 30 min ring limit: a backup every 2 min until it ends.
      expect(todayChain.first, DateTime(2026, 10, 13, 7, 2));
      expect(todayChain, hasLength(14));
      expect(todayChain.last, DateTime(2026, 10, 13, 7, 28));
      // Backups on the next two rings only.
      expect(kit.rings.where((r) => r.backup), hasLength(28));
      expect(kit.rings.map((r) => r.key).toSet(), hasLength(kit.rings.length));
      expect((await e.list()).single.id, 1);
    },
  );

  test('a short ring limit means a shorter chain', () async {
    await engine().upsert(Alarm(id: 1, hour: 7, minute: 0, maxRingMinutes: 10));
    expect(kit.rings.where((r) => r.backup), hasLength(4));
  });

  test('state survives a restart of the app', () async {
    await engine().upsert(Alarm(id: 1, hour: 7, minute: 0, label: 'Work'));
    final again = engine();
    expect((await again.list()).single.label, 'Work');
  });

  test(
    'once the time passes the alarm rings until the challenges are done',
    () async {
      final e = engine();
      await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
      now = DateTime(2026, 10, 13, 7, 3);
      expect(await e.ringingAlarmIds(), [1]);
      final progress = await e.getRingProgress();
      expect(progress!.alarmId, 1);
      expect(
        progress.startedAtMs,
        DateTime(2026, 10, 13, 7).millisecondsSinceEpoch,
      );
      // The backups that are still ahead stay armed while it rings.
      expect(
        times(kit.rings.where((r) => r.atMs > now.millisecondsSinceEpoch))
            .first,
        DateTime(2026, 10, 13, 7, 4),
      );
      // A one-shot alarm switches itself off once it rang.
      expect((await e.list()).single.enabled, isFalse);

      await e.stopRinging();
      expect(await e.ringingAlarmIds(), isEmpty);
      expect(kit.rings, isEmpty);
      expect(await e.getRingProgress(), isNull);
    },
  );

  test('a repeating alarm re-arms the next day after it rang', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0, repeatDays: {2, 3}));
    now = DateTime(2026, 10, 13, 7, 1);
    await e.stopRinging();
    final main = times(kit.rings.where((r) => !r.backup));
    expect(main.first, DateTime(2026, 10, 14, 7));
  });

  test('nobody there: after the ring limit it is no longer ringing', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0, maxRingMinutes: 10));
    now = DateTime(2026, 10, 13, 7, 11);
    expect(await e.ringingAlarmIds(), isEmpty);
    expect(kit.rings, isEmpty);
  });

  test('ring progress is kept between app launches', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
    now = DateTime(2026, 10, 13, 7, 3);
    final p = (await e.getRingProgress())!;
    await e.saveRingProgress(p.copyWith(stageIndex: 2));
    expect((await engine().getRingProgress())!.stageIndex, 2);
  });

  test('snooze rings again later with a fresh chain', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
    now = DateTime(2026, 10, 13, 7, 5);
    final at = await e.snooze(1, 9);
    await e.stopRinging();
    expect(at, DateTime(2026, 10, 13, 7, 14).millisecondsSinceEpoch);
    expect(times(kit.rings.where((r) => !r.backup)), [
      DateTime(2026, 10, 13, 7, 14),
    ]);
    expect(
      times(kit.rings.where((r) => r.backup)).first,
      DateTime(2026, 10, 13, 7, 16),
    );
    now = DateTime(2026, 10, 13, 7, 15);
    expect(await e.ringingAlarmIds(), [1]);
  });

  test('the check ring after a Stop is marked as the awake check', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0, repeatDays: {2}));
    now = DateTime(2026, 10, 13, 7, 4);
    await e.stopRinging();
    await e.followUp(1, 5);
    now = DateTime(2026, 10, 13, 7, 10);
    expect(await e.ringingAlarmIds(), [1]);
    expect((await e.getRingProgress())!.followUp, isTrue);
    await e.stopRinging();
    now = DateTime(2026, 10, 20, 7, 1);
    expect(await e.ringingAlarmIds(), [1]);
    expect((await e.getRingProgress())!.followUp, isFalse);
  });

  test(
    'skipNext skips one ring of a repeating alarm, ends a one-shot',
    () async {
      final e = engine();
      await e.upsert(Alarm(id: 1, hour: 7, minute: 0, repeatDays: {2, 3, 4}));
      await e.upsert(Alarm(id: 2, hour: 8, minute: 0));
      await e.skipNext(1);
      await e.skipNext(2);
      final mains = kit.rings.where((r) => !r.backup);
      expect(mains.every((r) => r.alarmId == 1), isTrue);
      expect(times(mains).first, DateTime(2026, 10, 14, 7));
      expect((await e.list()).firstWhere((a) => a.id == 2).enabled, isFalse);
    },
  );

  test('a disabled or deleted alarm never rings', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0, enabled: false));
    await e.upsert(Alarm(id: 2, hour: 7, minute: 0));
    await e.delete(2);
    expect(kit.rings, isEmpty);
    now = DateTime(2026, 10, 13, 7, 1);
    expect(await e.ringingAlarmIds(), isEmpty);
  });

  test('a series alarm pinned to a past instant is switched off', () async {
    final e = engine();
    final at = await e.upsert(
      Alarm(id: 1, hour: 5, minute: 0, onceAt: DateTime(2026, 10, 13, 5)),
    );
    expect(at, isNull);
    expect((await e.list()).single.enabled, isFalse);
  });

  test('permissions follow the AlarmKit authorization', () async {
    final e = engine();
    expect(await e.isSupported(), isTrue);
    expect((await e.permissions()).allGranted, isTrue);
    kit.auth = 'notDetermined';
    expect(
      (await e.permissions()).coreMissing,
      contains(PermissionKind.exactAlarm),
    );
    await e.openSettings(PermissionKind.exactAlarm);
    expect(kit.requested, 1);
    kit.auth = 'denied';
    await e.openSettings(PermissionKind.exactAlarm);
    expect(kit.settingsOpened, 1);
    kit.auth = 'unsupported';
    expect(await e.isSupported(), isFalse);
  });
  test('a ring the app never saw does not hide the next one', () async {
    final e = engine();
    await e.upsert(
      Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1, 2, 3, 4, 5, 6, 7}),
    );
    // Tuesday's ring was dismissed in the system alert only; the app is
    // first opened during Wednesday's ring.
    now = DateTime(2026, 10, 14, 7, 1);
    expect(await e.ringingAlarmIds(), [1]);
    expect(
      (await e.getRingProgress())!.startedAtMs,
      DateTime(2026, 10, 14, 7).millisecondsSinceEpoch,
    );
    expect(
      times(kit.rings.where((r) => r.atMs > now.millisecondsSinceEpoch)).first,
      DateTime(2026, 10, 14, 7, 2),
    );
  });

  test('the ring sounding now stays armed while the app looks at it', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
    now = DateTime(2026, 10, 13, 7, 0, 20);
    await e.list();
    expect(
      kit.rings.map((r) => r.key),
      contains('1@${DateTime(2026, 10, 13, 7).millisecondsSinceEpoch}'),
    );
  });

  test('a failed sync does not fail the call, and is retried', () async {
    final e = engine();
    kit.failSync = StateError('AlarmKit down');
    expect(await e.upsert(Alarm(id: 1, hour: 7, minute: 0)), isNotNull);
    expect(kit.rings, isEmpty);
    kit.failSync = null;
    await e.list();
    expect(kit.rings, isNotEmpty);
  });

  test('calls that change nothing do not re-sync', () async {
    final e = engine();
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
    final before = kit.syncs;
    await e.ringingAlarmIds();
    await e.list();
    expect(kit.syncs, before);
  });

  test(
    'a regular ring time is recomputed on every call (time zone moves)',
    () async {
      final e = engine();
      await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
      // As if saved in another zone: the stored instant is an hour off.
      final alarms = store.saved!['alarms']! as List;
      (alarms.single as Map)['nextAtMs'] = DateTime(
        2026,
        10,
        13,
        8,
      ).millisecondsSinceEpoch;
      final fresh = engine();
      await fresh.list();
      expect(
        times(kit.rings.where((r) => !r.backup)).first,
        DateTime(2026, 10, 13, 7),
      );
    },
  );

  test('an unreadable state file starts empty instead of breaking', () async {
    final dir = await Directory.systemTemp.createTemp('ios_state');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/alarms.json').writeAsString('{not json');
    final e = IosAlarmEngine(
      kit: kit,
      store: FileIosStateStore(() async => dir),
      now: () => now,
    );
    expect(await e.list(), isEmpty);
    await e.upsert(Alarm(id: 1, hour: 7, minute: 0));
    expect(await File('${dir.path}/alarms.json').exists(), isTrue);
  });
}
