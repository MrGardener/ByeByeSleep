import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../alarm.dart';
import '../alarm_platform.dart';

/// One system alarm the iPhone should ring. [key] is stable for the same
/// alarm and instant, so syncing the same plan twice changes nothing.
class IosRing {
  const IosRing({
    required this.alarmId,
    required this.atMs,
    required this.title,
    this.backup = false,
  });

  final int alarmId;
  final int atMs;
  final String title;

  /// One of the backups that ring every 2 minutes until the challenges are
  /// done: stopping the system alert alone only buys 2 minutes (spec §5.3).
  final bool backup;

  String get key => '$alarmId@$atMs';

  Map<String, Object?> toMap() => {
    'key': key,
    'alarmId': alarmId,
    'atMs': atMs,
    'title': title,
    'backup': backup,
  };
}

/// Native side (ios/Runner/AlarmKitChannel.swift): rings the given instants
/// with AlarmKit, which sounds through silent mode and Focus.
abstract class IosAlarmKit {
  /// 'authorized', 'denied', 'notDetermined', or 'unsupported' (before iOS 26).
  Future<String> authorization();
  Future<String> requestAuthorization();

  /// Makes the scheduled system alarms exactly [rings].
  Future<void> sync(List<IosRing> rings);
  Future<void> openSettings();
}

class MethodChannelIosAlarmKit implements IosAlarmKit {
  static const _channel = MethodChannel('byebyesleep/alarmkit');

  @override
  Future<String> authorization() async {
    try {
      return await _channel.invokeMethod<String>('authorization') ??
          'unsupported';
    } on MissingPluginException {
      return 'unsupported';
    }
  }

  @override
  Future<String> requestAuthorization() async =>
      await _channel.invokeMethod<String>('requestAuthorization') ??
      'unsupported';

  @override
  Future<void> sync(List<IosRing> rings) =>
      _channel.invokeMethod<void>('sync', [for (final r in rings) r.toMap()]);

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}

abstract class IosStateStore {
  Future<Map<String, Object?>?> load();
  Future<void> save(Map<String, Object?> state);
}

/// `alarms.json` in the app's documents folder.
class FileIosStateStore implements IosStateStore {
  FileIosStateStore(this._dir);

  final Future<Directory> Function() _dir;

  Future<File> get _file async => File('${(await _dir()).path}/alarms.json');

  @override
  Future<Map<String, Object?>?> load() async {
    final file = await _file;
    if (!await file.exists()) return null;
    return (jsonDecode(await file.readAsString()) as Map)
        .cast<String, Object?>();
  }

  @override
  Future<void> save(Map<String, Object?> state) async {
    final file = await _file;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(state), flush: true);
    await tmp.rename(file.path);
  }
}

/// Earliest instant strictly after [after] at the alarm's time on an allowed
/// day (port of NextTrigger.kt).
DateTime nextRing(Alarm a, DateTime after) {
  for (var offset = 0; offset <= 7; offset++) {
    final at = DateTime(
      after.year,
      after.month,
      after.day + offset,
      a.hour,
      a.minute,
    );
    if (a.repeatDays.isNotEmpty && !a.repeatDays.contains(at.weekday)) {
      continue;
    }
    if (at.isAfter(after)) return at;
  }
  throw StateError('No ring within 8 days for alarm ${a.id}');
}

const _backupEvery = Duration(minutes: 2);
const _maxBackups = 10;

/// A ring this close to the check time is the "check I'm awake" ring.
const _checkWindowMs = 5 * 60000;

int _backups(Alarm a) => min(_maxBackups, a.maxRingMinutes ~/ 2);

class _Entry {
  _Entry(this.alarm, {this.nextAtMs, this.followUpAtMs});

  factory _Entry.fromJson(Map<String, Object?> j) => _Entry(
    Alarm.fromMap((j['alarm']! as Map).cast<Object?, Object?>()),
    nextAtMs: (j['nextAtMs'] as num?)?.toInt(),
    followUpAtMs: (j['followUpAtMs'] as num?)?.toInt(),
  );

  Alarm alarm;

  /// When it rings next (a snooze or the regular time), null = never.
  int? nextAtMs;
  int? followUpAtMs;

  Map<String, Object?> toJson() => {
    'alarm': alarm.toMap(),
    'nextAtMs': ?nextAtMs,
    'followUpAtMs': ?followUpAtMs,
  };
}

class _Ringing {
  _Ringing(this.firedAtMs, {this.followUp = false});

  factory _Ringing.fromJson(Map<String, Object?> j) => _Ringing(
    (j['firedAtMs']! as num).toInt(),
    followUp: j['followUp'] == true,
  );

  final int firedAtMs;
  final bool followUp;

  Map<String, Object?> toJson() => {
    'firedAtMs': firedAtMs,
    'followUp': followUp,
  };
}

/// The iPhone alarm engine. iOS runs no app code when an alarm goes off, so
/// what happened since the app last ran is worked out from the clock on
/// every call: an alarm whose time passed (within its ring limit) is ringing
/// until its challenges are done. The system alarms are re-synced each time.
class IosAlarmEngine implements AlarmPlatform {
  IosAlarmEngine({
    required IosAlarmKit kit,
    required IosStateStore store,
    DateTime Function() now = DateTime.now,
  }) : _alarmKit = kit,
       _stateStore = store,
       _clock = now;

  final IosAlarmKit _alarmKit;
  final IosStateStore _stateStore;
  final DateTime Function() _clock;

  final _entries = <int, _Entry>{};
  final _ringing = <int, _Ringing>{};
  RingProgress? _progress;
  bool _loaded = false;
  Future<void> _queue = Future.value();

  /// Runs [body] after earlier calls, on fresh state, then saves and syncs.
  Future<T> _run<T>(T Function(int nowMs) body) {
    final result = _queue.then((_) async {
      await _load();
      final nowMs = _clock().millisecondsSinceEpoch;
      _catchUp(nowMs);
      final value = body(nowMs);
      await _stateStore.save(_toJson());
      await _alarmKit.sync(_plan(nowMs));
      return value;
    });
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _load() async {
    if (_loaded) return;
    final j = await _stateStore.load();
    if (j != null) {
      for (final e in (j['alarms'] as List? ?? const [])) {
        final entry = _Entry.fromJson((e as Map).cast<String, Object?>());
        _entries[entry.alarm.id] = entry;
      }
      final ringing = (j['ringing'] as Map?) ?? const {};
      for (final MapEntry(:key, :value) in ringing.entries) {
        _ringing[int.parse(key as String)] = _Ringing.fromJson(
          (value as Map).cast<String, Object?>(),
        );
      }
      if (j['progress'] case final Map<Object?, Object?> p) {
        _progress = RingProgress.fromMap(p);
      }
    }
    _loaded = true;
  }

  Map<String, Object?> _toJson() => {
    'alarms': [for (final e in _entries.values) e.toJson()],
    'ringing': {
      for (final MapEntry(:key, :value) in _ringing.entries)
        '$key': value.toJson(),
    },
    if (_progress != null) 'progress': _progress!.toMap(),
  };

  /// Applies every ring that went off since the app last ran.
  void _catchUp(int nowMs) {
    for (final e in _entries.values) {
      final firedAt = e.nextAtMs;
      if (firedAt == null || firedAt > nowMs) continue;
      final check =
          e.followUpAtMs != null &&
          (firedAt - e.followUpAtMs!).abs() <= _checkWindowMs;
      e.followUpAtMs = null;
      if (e.alarm.isRepeating && e.alarm.onceAt == null) {
        var next = nextRing(
          e.alarm,
          DateTime.fromMillisecondsSinceEpoch(firedAt),
        );
        while (next.millisecondsSinceEpoch <= nowMs) {
          next = nextRing(e.alarm, next);
        }
        e.nextAtMs = next.millisecondsSinceEpoch;
      } else {
        e.alarm = e.alarm.copyWith(enabled: false);
        e.nextAtMs = null;
      }
      _ringing[e.alarm.id] = _Ringing(firedAt, followUp: check);
    }
    // Nobody stopped it within its ring limit: it stopped by itself.
    _ringing.removeWhere((id, r) {
      final limit = _entries[id]?.alarm.maxRingMinutes ?? Alarm.defaultMaxRing;
      return r.firedAtMs + limit * 60000 <= nowMs;
    });
    if (_progress != null && !_ringing.containsKey(_progress!.alarmId)) {
      _progress = null;
    }
  }

  /// The system alarms to ring: each alarm's next ring with its backups,
  /// one more regular ring ahead, and the remaining backups of rings now.
  List<IosRing> _plan(int nowMs) {
    final rings = <IosRing>[];
    void ringAt(Alarm a, int atMs) {
      final title = a.label.isEmpty ? 'Alarm ${a.timeLabel}' : a.label;
      if (atMs > nowMs) {
        rings.add(IosRing(alarmId: a.id, atMs: atMs, title: title));
      }
      for (var k = 1; k <= _backups(a); k++) {
        final at = atMs + k * _backupEvery.inMilliseconds;
        if (at > nowMs) {
          rings.add(
            IosRing(alarmId: a.id, atMs: at, title: title, backup: true),
          );
        }
      }
    }

    for (final e in _entries.values) {
      final next = e.nextAtMs;
      if (next != null) {
        ringAt(e.alarm, next);
        // If the app is not opened after this ring, the following one is
        // already armed.
        if (e.alarm.enabled && e.alarm.isRepeating && e.alarm.onceAt == null) {
          final after = nextRing(
            e.alarm,
            DateTime.fromMillisecondsSinceEpoch(next),
          );
          ringAt(e.alarm, after.millisecondsSinceEpoch);
        }
      }
      final r = _ringing[e.alarm.id];
      if (r != null) ringAt(e.alarm, r.firedAtMs);
    }
    rings.sort((a, b) => a.atMs.compareTo(b.atMs));
    return rings;
  }

  int? _regular(_Entry e, int nowMs) {
    final a = e.alarm;
    if (!a.enabled) return null;
    if (a.onceAt case final at?) {
      if (at.millisecondsSinceEpoch > nowMs) return at.millisecondsSinceEpoch;
      e.alarm = a.copyWith(enabled: false);
      return null;
    }
    return nextRing(
      a,
      DateTime.fromMillisecondsSinceEpoch(nowMs),
    ).millisecondsSinceEpoch;
  }

  @override
  Future<bool> isSupported() async =>
      await _alarmKit.authorization() != 'unsupported';

  @override
  Future<List<Alarm>> list() =>
      _run((_) => [for (final e in _entries.values) e.alarm]);

  @override
  Future<int?> upsert(Alarm alarm) => _run((nowMs) {
    final e = _Entry(alarm);
    _entries[alarm.id] = e;
    return e.nextAtMs = _regular(e, nowMs);
  });

  @override
  Future<void> delete(int id) => _run((_) {
    _entries.remove(id);
    _ringing.remove(id);
  });

  /// The challenges are done (or the alarm was snoozed): silence the
  /// backups of every ring now.
  @override
  Future<void> stopRinging() => _run((_) {
    _ringing.clear();
    _progress = null;
  });

  @override
  Future<int> snooze(int id, int minutes) => _run((nowMs) {
    final at = nowMs + minutes * 60000;
    for (final ringingId in {..._ringing.keys, id}) {
      _entries[ringingId]?.nextAtMs = at;
    }
    _ringing.clear();
    _progress = null;
    return at;
  });

  @override
  Future<int> followUp(int id, int minutes) => _run((nowMs) {
    final at = nowMs + minutes * 60000;
    final e = _entries[id];
    if (e != null) {
      e.nextAtMs = at;
      e.followUpAtMs = at;
    }
    return at;
  });

  @override
  Future<void> skipNext(int id) => _run((nowMs) {
    final e = _entries[id];
    if (e == null || !e.alarm.enabled) return;
    if (!e.alarm.isRepeating || e.alarm.onceAt != null) {
      e.alarm = e.alarm.copyWith(enabled: false);
      e.nextAtMs = null;
      return;
    }
    final skipped = nextRing(
      e.alarm,
      DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
    e.nextAtMs = nextRing(e.alarm, skipped).millisecondsSinceEpoch;
    e.followUpAtMs = null;
  });

  @override
  Future<List<int>> ringingAlarmIds() =>
      _run((_) => _ringing.keys.toList()..sort());

  @override
  Future<RingProgress?> getRingProgress() => _run((_) {
    if (_progress != null) return _progress;
    if (_ringing.isEmpty) return null;
    final id = (_ringing.keys.toList()..sort()).first;
    final r = _ringing[id]!;
    return _progress = RingProgress(
      alarmId: id,
      stageIndex: 0,
      startedAtMs: r.firedAtMs,
      followUp: r.followUp,
    );
  });

  @override
  Future<void> saveRingProgress(RingProgress progress) =>
      _run((_) => _progress = progress);

  /// The system sets the alarm volume on iPhone.
  @override
  Future<void> setRingLevel(double level) async {}

  @override
  Future<PermissionStatus> permissions() async {
    final ok = await _alarmKit.authorization() == 'authorized';
    return PermissionStatus({
      PermissionKind.exactAlarm: ok,
      PermissionKind.notifications: ok,
      PermissionKind.fullScreenIntent: true,
      PermissionKind.ignoreBatteryOptimizations: true,
    });
  }

  @override
  Future<void> openSettings(PermissionKind kind) async {
    if (await _alarmKit.authorization() == 'notDetermined') {
      await _alarmKit.requestAuthorization();
    } else {
      await _alarmKit.openSettings();
    }
  }
}
