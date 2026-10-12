import 'package:flutter/services.dart';

import 'alarm.dart';

/// Permissions the alarm engine needs to ring reliably.
enum PermissionKind {
  exactAlarm,
  fullScreenIntent,
  notifications,
  ignoreBatteryOptimizations,

  /// Needed only by challenges that use them; asked for during setup.
  activityRecognition,
  camera,
}

/// Permissions every alarm needs to ring at all.
const corePermissionKinds = {
  PermissionKind.exactAlarm,
  PermissionKind.fullScreenIntent,
  PermissionKind.notifications,
  PermissionKind.ignoreBatteryOptimizations,
};

class PermissionStatus {
  const PermissionStatus(this.granted);

  /// Used when the platform has no alarm engine yet (iOS in Phase 0).
  static const PermissionStatus unknownAllGranted = PermissionStatus({});

  final Map<PermissionKind, bool> granted;

  List<PermissionKind> get missing => [
    for (final k in PermissionKind.values)
      if (granted[k] == false) k,
  ];

  bool get allGranted => missing.isEmpty;

  List<PermissionKind> get coreMissing =>
      missing.where(corePermissionKinds.contains).toList();
}

/// How far the user got through a ringing alarm's stages. Kept natively so it
/// survives the ring screen being recreated.
class RingProgress {
  const RingProgress({
    required this.alarmId,
    required this.stageIndex,
    required this.startedAtMs,
  });

  factory RingProgress.fromMap(Map<Object?, Object?> m) => RingProgress(
    alarmId: m['alarmId']! as int,
    stageIndex: m['stageIndex']! as int,
    startedAtMs: m['startedAtMs']! as int,
  );

  final int alarmId;
  final int stageIndex;
  final int startedAtMs;

  RingProgress copyWith({int? stageIndex}) => RingProgress(
    alarmId: alarmId,
    stageIndex: stageIndex ?? this.stageIndex,
    startedAtMs: startedAtMs,
  );

  Map<String, Object?> toMap() => {
    'alarmId': alarmId,
    'stageIndex': stageIndex,
    'startedAtMs': startedAtMs,
  };

  @override
  bool operator ==(Object other) =>
      other is RingProgress &&
      other.alarmId == alarmId &&
      other.stageIndex == stageIndex &&
      other.startedAtMs == startedAtMs;

  @override
  int get hashCode => Object.hash(alarmId, stageIndex, startedAtMs);
}

/// Bridge to the native alarm engine.
abstract class AlarmPlatform {
  /// False when this platform has no alarm engine yet (iOS before Phase 2).
  Future<bool> isSupported();

  Future<List<Alarm>> list();

  /// Saves the alarm; returns the next trigger (epoch ms), or null if disabled.
  Future<int?> upsert(Alarm alarm);

  Future<void> delete(int id);

  Future<void> stopRinging();

  /// Snoozes a ringing alarm; returns the snooze trigger (epoch ms).
  Future<int> snooze(int id, int minutes);

  Future<PermissionStatus> permissions();

  Future<void> openSettings(PermissionKind kind);

  /// Progress of the alarm ringing now, or null if none is known.
  Future<RingProgress?> getRingProgress();

  Future<void> saveRingProgress(RingProgress progress);

  /// Alarm loudness as a fraction of full volume (0.0–1.0).
  Future<void> setRingLevel(double level);
}

class MethodChannelAlarmPlatform implements AlarmPlatform {
  MethodChannelAlarmPlatform([
    this._channel = const MethodChannel('byebyesleep/alarm'),
  ]);

  final MethodChannel _channel;

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> isSupported() async {
    try {
      await _channel.invokeMethod<Object?>('list');
      return true;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<Alarm>> list() async {
    final raw = await _invoke<List<Object?>>('list') ?? const [];
    return [for (final m in raw) Alarm.fromMap(m! as Map<Object?, Object?>)];
  }

  @override
  Future<int?> upsert(Alarm alarm) => _invoke<int>('upsert', alarm.toMap());

  @override
  Future<void> delete(int id) => _invoke<void>('delete', {'id': id});

  @override
  Future<void> stopRinging() => _invoke<void>('stopRinging');

  @override
  Future<int> snooze(int id, int minutes) async =>
      await _invoke<int>('snooze', {'id': id, 'minutes': minutes}) ?? 0;

  @override
  Future<PermissionStatus> permissions() async {
    final raw = await _invoke<Map<Object?, Object?>>('permissions');
    if (raw == null) return PermissionStatus.unknownAllGranted;
    return PermissionStatus({
      for (final k in PermissionKind.values)
        if (raw[k.name] is bool) k: raw[k.name]! as bool,
    });
  }

  @override
  Future<void> openSettings(PermissionKind kind) =>
      _invoke<void>('openSettings', {'kind': kind.name});

  @override
  Future<RingProgress?> getRingProgress() async {
    final raw = await _invoke<Map<Object?, Object?>>('getRingProgress');
    return raw == null ? null : RingProgress.fromMap(raw);
  }

  @override
  Future<void> saveRingProgress(RingProgress progress) =>
      _invoke<void>('saveRingProgress', progress.toMap());

  @override
  Future<void> setRingLevel(double level) =>
      _invoke<void>('setRingLevel', {'level': level});
}
