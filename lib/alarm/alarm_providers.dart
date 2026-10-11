import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alarm.dart';
import 'alarm_platform.dart';

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

class AlarmListNotifier extends AsyncNotifier<List<Alarm>> {
  AlarmPlatform get _platform => ref.read(alarmPlatformProvider);

  @override
  Future<List<Alarm>> build() async => _sorted(await _platform.list());

  Future<Alarm> add({
    required int hour,
    required int minute,
    Set<int> repeatDays = const {},
    String label = '',
  }) async {
    final current = await future;
    final nextId = current.fold(0, (m, a) => a.id > m ? a.id : m) + 1;
    final alarm = Alarm(
      id: nextId,
      hour: hour,
      minute: minute,
      repeatDays: repeatDays,
      label: label,
    );
    await save(alarm);
    return alarm;
  }

  Future<void> save(Alarm alarm) async {
    await _platform.upsert(alarm);
    final current = await future;
    state = AsyncData(
      _sorted([...current.where((a) => a.id != alarm.id), alarm]),
    );
  }

  Future<void> setEnabled(int id, bool enabled) async {
    final alarm = (await future).firstWhere((a) => a.id == id);
    await save(alarm.copyWith(enabled: enabled));
  }

  Future<void> remove(int id) async {
    await _platform.delete(id);
    final current = await future;
    state = AsyncData(current.where((a) => a.id != id).toList());
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
