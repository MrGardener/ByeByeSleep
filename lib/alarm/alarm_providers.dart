import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenges/core/camera.dart';
import 'alarm.dart';
import 'alarm_platform.dart';
import 'guard.dart';
import 'series.dart';
import 'stage_config.dart';

final alarmPlatformProvider = Provider<AlarmPlatform>(
  (_) => MethodChannelAlarmPlatform(),
);

/// Photo files the alarms still use: reminder photos and photo-match
/// references.
Set<String> photosInUse(List<Alarm> alarms) => {
  for (final a in alarms) ...[
    ?a.reminder?.photoPath,
    for (final s in a.stages)
      if (s.params['photos'] case final List<Object?> photos)
        for (final p in photos)
          if (p is String) p,
  ],
};

final alarmListProvider = AsyncNotifierProvider<AlarmListNotifier, List<Alarm>>(
  AlarmListNotifier.new,
);

/// Permission health for the preflight banner; invalidate to re-check.
final permissionStatusProvider = FutureProvider<PermissionStatus>(
  (ref) => ref.watch(alarmPlatformProvider).permissions(),
);

final alarmSupportedProvider = FutureProvider<bool>(
  (ref) => ref.watch(alarmPlatformProvider).isSupported(),
);

class AlarmListNotifier extends AsyncNotifier<List<Alarm>> {
  AlarmPlatform get _platform => ref.read(alarmPlatformProvider);

  @override
  Future<List<Alarm>> build() async => _sorted(await _platform.list());

  Future<Alarm> add({
    required int hour,
    required int minute,
    Set<int> repeatDays = const {},
    String label = '',
    List<StageConfig> stages = defaultStages,
    int pauseSeconds = 0,
  }) => addAlarm(
    Alarm(
      id: 0,
      hour: hour,
      minute: minute,
      repeatDays: repeatDays,
      label: label,
      stages: stages,
      pauseSeconds: pauseSeconds,
    ),
  );

  /// Saves [draft] as a new main alarm under a fresh id.
  Future<Alarm> addAlarm(Alarm draft) async {
    final current = await future;
    final taken = {for (final a in current) a.id};
    // Count from main alarms only: series ids (main × 100 + k) would make
    // ids grow past what the native side can hold.
    var id =
        current
            .where((a) => !a.isSeriesChild)
            .fold(0, (m, a) => a.id > m ? a.id : m) +
        1;
    while (taken.contains(id)) {
      id++;
    }
    final alarm = draft.copyWith(id: id, parentId: () => null);
    await save(alarm);
    return alarm;
  }

  /// The other alarms of [main]'s series as they would be saved, with ids:
  /// its own alarms keep theirs, new ones never take an id that belongs to
  /// another alarm (e.g. one split off earlier) and stay below [maxAlarmId].
  List<Alarm> planSeries(Alarm main, List<Alarm> current) {
    final kids = seriesChildren(main, now: ref.read(nowProvider)());
    final own = [
      for (final a in current)
        if (a.parentId == main.id) a.id,
    ]..sort();
    final used = {
      main.id,
      for (final a in current)
        if (a.parentId != main.id) a.id,
    };
    var next = [main.id, for (final a in current) a.id].reduce(max) + 1;
    int fresh() {
      while (used.contains(next)) {
        next++;
      }
      return next;
    }

    final planned = <Alarm>[];
    for (var i = 0; i < kids.length; i++) {
      final preferred = seriesChildId(main.id, i + 1);
      final id = i < own.length
          ? own[i]
          : preferred < maxAlarmId && !used.contains(preferred)
          ? preferred
          : fresh();
      used.add(id);
      planned.add(kids[i].copyWith(id: id));
    }
    return planned;
  }

  /// Saves [alarm]; a main alarm also saves its series and drops alarms of
  /// its old series that no longer belong. The main alarm is written last;
  /// if anything fails, what was changed is put back and the list reloaded,
  /// so a series is never left half saved.
  Future<void> save(Alarm alarm) async {
    final current = await future;
    final children = alarm.isSeriesChild
        ? const <Alarm>[]
        : planSeries(alarm, current);
    final keep = {for (final c in children) c.id};
    final stale = [
      for (final a in current)
        if (a.parentId == alarm.id && !keep.contains(a.id)) a.id,
    ];
    await _apply(current, [
      for (final id in stale) (id, null),
      for (final c in children) (c.id, c),
      (alarm.id, alarm),
    ]);
    final changed = {alarm.id, ...keep, ...stale};
    state = AsyncData(
      _sorted([
        ...current.where((a) => !changed.contains(a.id)),
        alarm,
        ...children,
      ]),
    );
    _prunePhotos();
  }

  /// Writes [changes] in order (null = delete). On a failure, puts back the
  /// alarms already changed (best effort), reloads the list and rethrows.
  Future<void> _apply(List<Alarm> current, List<(int, Alarm?)> changes) async {
    final before = {for (final a in current) a.id: a};
    final touched = <int>[];
    try {
      for (final (id, alarm) in changes) {
        touched.add(id);
        alarm == null
            ? await _platform.delete(id)
            : await _platform.upsert(alarm);
      }
    } catch (_) {
      for (final id in touched.reversed) {
        try {
          final old = before[id];
          old == null
              ? await _platform.delete(id)
              : await _platform.upsert(old);
        } catch (_) {
          // Keep restoring the others.
        }
      }
      try {
        state = AsyncData(_sorted(await _platform.list()));
      } catch (_) {
        state = AsyncData(_sorted(current));
      }
      rethrow;
    }
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final alarm = (await future).firstWhere((a) => a.id == id);
    await save(alarm.copyWith(enabled: enabled));
  }

  /// Turns a series into independent alarms at the same times: each can
  /// then be edited, switched off or deleted on its own.
  Future<void> split(int mainId) async {
    final current = await future;
    final main = current.firstWhere((a) => a.id == mainId);
    for (final child in current.where((a) => a.parentId == mainId)) {
      await save(child.copyWith(parentId: () => null));
    }
    await save(main.copyWith(series: () => null));
  }

  /// Removes the alarm and its series (the series first, the main alarm
  /// last). On a failure everything is put back and the error rethrown.
  Future<void> remove(int id) async {
    final current = state.value ?? await future;
    final gone = [
      for (final a in current)
        if (a.parentId == id) a.id,
      id,
    ];
    state = AsyncData(current.where((a) => !gone.contains(a.id)).toList());
    await _apply(current, [for (final g in gone) (g, null)]);
    _prunePhotos();
  }

  /// After a successful change: let go of photos no alarm uses any more.
  /// Never after a failure, when the list may be incomplete.
  void _prunePhotos() {
    final alarms = state.value;
    if (alarms == null) return;
    ref
        .read(photoStoreProvider)
        .keepOnly(photosInUse(alarms))
        .catchError((Object _) {});
  }

  static List<Alarm> _sorted(List<Alarm> alarms) => [...alarms]
    ..sort(
      (a, b) => a.hour != b.hour
          ? a.hour.compareTo(b.hour)
          : a.minute != b.minute
          ? a.minute.compareTo(b.minute)
          : a.id.compareTo(b.id),
    );
}
