import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';

/// In-memory [AlarmPlatform] that records calls as "method[:args]" strings.
class FakeAlarmPlatform implements AlarmPlatform {
  FakeAlarmPlatform({
    Iterable<Alarm> seed = const [],
    this.permissionStatus = PermissionStatus.unknownAllGranted,
    this.supported = true,
  }) {
    for (final a in seed) {
      stored[a.id] = a;
    }
  }

  final Map<int, Alarm> stored = {};
  final List<String> calls = [];
  PermissionStatus permissionStatus;
  bool supported;

  RingProgress? ringProgress;

  /// When set, list/getRingProgress throw this (native side broken).
  Object? readFailWith;

  /// When set, upsert/delete/snooze throw this (simulates a native failure).
  Object? failWith;

  void _maybeFail() {
    final f = failWith;
    if (f != null) throw f;
  }

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<List<Alarm>> list() async {
    calls.add('list');
    final f = readFailWith;
    if (f != null) throw f;
    return stored.values.toList();
  }

  @override
  Future<int?> upsert(Alarm alarm) async {
    calls.add('upsert:${alarm.id}');
    _maybeFail();
    stored[alarm.id] = alarm;
    return alarm.enabled ? 1 : null;
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete:$id');
    _maybeFail();
    stored.remove(id);
  }

  @override
  Future<void> stopRinging() async => calls.add('stopRinging');

  @override
  Future<int> snooze(int id, int minutes) async {
    calls.add('snooze:$id:$minutes');
    _maybeFail();
    return 1;
  }

  @override
  Future<PermissionStatus> permissions() async => permissionStatus;

  @override
  Future<void> openSettings(PermissionKind kind) async =>
      calls.add('openSettings:${kind.name}');

  @override
  Future<RingProgress?> getRingProgress() async {
    final f = readFailWith;
    if (f != null) throw f;
    return ringProgress;
  }

  @override
  Future<void> saveRingProgress(RingProgress progress) async {
    calls.add('saveRingProgress:${progress.alarmId}:${progress.stageIndex}');
    ringProgress = progress;
  }

  @override
  Future<void> setRingLevel(double level) async =>
      calls.add('setRingLevel:$level');
}
