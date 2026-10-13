import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm.dart';
import 'alarm_platform.dart';
import 'series.dart';
import 'stage_config.dart';

final alarmPlatformProvider = Provider<AlarmPlatform>(
  (_) => MethodChannelAlarmPlatform(),
);

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

  /// Saves [alarm]; a main alarm also saves its series and drops alarms of
  /// its old series that no longer exist. On a failure the list is reloaded
  /// from the platform, so it never shows a half-saved series.
  Future<void> save(Alarm alarm) async {
    final current = await future;
    final children = alarm.isSeriesChild
        ? const <Alarm>[]
        : seriesChildren(alarm);
    final keep = {for (final c in children) c.id};
    final stale = [
      for (final a in current)
        if (a.parentId == alarm.id && !keep.contains(a.id)) a.id,
    ];
    try {
      await _platform.upsert(alarm);
      for (final c in children) {
        await _platform.upsert(c);
      }
      for (final id in stale) {
        await _platform.delete(id);
      }
    } catch (_) {
      state = AsyncData(_sorted(await _platform.list()));
      rethrow;
    }
    final changed = {alarm.id, ...keep, ...stale};
    state = AsyncData(
      _sorted([
        ...current.where((a) => !changed.contains(a.id)),
        alarm,
        ...children,
      ]),
    );
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

  /// Removes the alarm (and its series) from the list immediately; restores
  /// them if the platform fails, then rethrows.
  Future<void> remove(int id) async {
    final current = state.value ?? await future;
    final gone = {
      id,
      for (final a in current)
        if (a.parentId == id) a.id,
    };
    state = AsyncData(current.where((a) => !gone.contains(a.id)).toList());
    try {
      for (final g in gone) {
        await _platform.delete(g);
      }
    } catch (_) {
      state = AsyncData(_sorted(current));
      rethrow;
    }
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
