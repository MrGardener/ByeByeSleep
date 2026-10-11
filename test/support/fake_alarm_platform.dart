import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';

/// In-memory [AlarmPlatform] that records calls as "method[:args]" strings.
class FakeAlarmPlatform implements AlarmPlatform {
  FakeAlarmPlatform({
    Iterable<Alarm> seed = const [],
    this.permissionStatus = PermissionStatus.unknownAllGranted,
  }) {
    for (final a in seed) {
      stored[a.id] = a;
    }
  }

  final Map<int, Alarm> stored = {};
  final List<String> calls = [];
  PermissionStatus permissionStatus;

  @override
  Future<List<Alarm>> list() async {
    calls.add('list');
    return stored.values.toList();
  }

  @override
  Future<int?> upsert(Alarm alarm) async {
    calls.add('upsert:${alarm.id}');
    stored[alarm.id] = alarm;
    return alarm.enabled ? 1 : null;
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete:$id');
    stored.remove(id);
  }

  @override
  Future<void> stopRinging() async => calls.add('stopRinging');

  @override
  Future<int> snooze(int id, int minutes) async {
    calls.add('snooze:$id:$minutes');
    return 1;
  }

  @override
  Future<PermissionStatus> permissions() async => permissionStatus;

  @override
  Future<void> openSettings(PermissionKind kind) async =>
      calls.add('openSettings:${kind.name}');
}
