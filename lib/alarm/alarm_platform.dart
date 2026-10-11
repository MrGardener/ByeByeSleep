import 'package:flutter/services.dart';

import 'alarm.dart';

/// Permissions the alarm engine needs to ring reliably.
enum PermissionKind {
  exactAlarm,
  fullScreenIntent,
  notifications,
  ignoreBatteryOptimizations,
}

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
}
