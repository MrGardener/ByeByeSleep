import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/guard.dart' show nowProvider;
import '../alarm/ios/ios_engine.dart' show nextRing;
import 'bedtime.dart';

/// The bedtime reminder on iPhone. Native code cannot see the alarms (they
/// live in Dart, ios_engine.dart), so the reminders are worked out here and
/// handed to iOS as local notifications, a week ahead.

/// Whether this is an iPhone; tests override it.
final isIosProvider = Provider<bool>((_) => Platform.isIOS);

/// A reminder: when it shows, and the alarm it is for.
class BedtimeReminder {
  const BedtimeReminder({required this.at, required this.alarm});

  final DateTime at;
  final DateTime alarm;
}

/// Rings this close after a morning's first ring belong to that morning (a
/// series).
const _sameMorning = Duration(hours: 4);

DateTime? _firstRing(List<Alarm> alarms, DateTime after) {
  DateTime? first;
  for (final a in alarms) {
    if (!a.enabled) continue;
    final once = a.onceAt;
    final at = once != null
        ? (once.isAfter(after) ? once : null)
        : nextRing(a, after);
    if (at != null && (first == null || at.isBefore(first))) first = at;
  }
  return first;
}

/// The next morning's first alarm minus the sleep goal, still ahead of
/// [now] (port of Bedtime.next in Bedtime.kt).
BedtimeReminder? nextBedtime(
  List<Alarm> alarms,
  DateTime now,
  int sleepMinutes,
) {
  var after = now;
  for (var i = 0; i < 8; i++) {
    final ring = _firstRing(alarms, after);
    if (ring == null) return null;
    final bed = ring.subtract(Duration(minutes: sleepMinutes));
    if (bed.isAfter(now)) return BedtimeReminder(at: bed, alarm: ring);
    // Bedtime for this morning has passed: the next morning's first ring.
    after = ring.add(_sameMorning);
  }
  return null;
}

/// The next [count] reminders, one per morning.
List<BedtimeReminder> planBedtimes(
  List<Alarm> alarms,
  DateTime now,
  int sleepMinutes, {
  int count = 7,
}) {
  final plan = <BedtimeReminder>[];
  var from = now;
  while (plan.length < count) {
    final r = nextBedtime(alarms, from, sleepMinutes);
    if (r == null) break;
    plan.add(r);
    from = r.at;
  }
  return plan;
}

/// Same words as Bedtime.text in Bedtime.kt.
String bedtimeText(DateTime alarm, int sleepMinutes) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'Your alarm rings at ${two(alarm.hour)}:${two(alarm.minute)} — '
      'go to bed now for ${sleepLabel(sleepMinutes)} of sleep.';
}

/// Local notifications (native side: NotifyChannel in AppDelegate.swift).
abstract class LocalNotifier {
  Future<void> schedule(String id, DateTime at, String title, String body);

  /// Cancels the pending notifications whose id starts with [prefix].
  Future<void> cancelPrefix(String prefix);
}

class MethodChannelLocalNotifier implements LocalNotifier {
  static const _channel = MethodChannel('byebyesleep/notify');

  @override
  Future<void> schedule(String id, DateTime at, String title, String body) =>
      _channel.invokeMethod<void>('schedule', {
        'id': id,
        'atMs': at.millisecondsSinceEpoch,
        'title': title,
        'body': body,
      });

  @override
  Future<void> cancelPrefix(String prefix) =>
      _channel.invokeMethod<void>('cancelPrefix', {'prefix': prefix});
}

final localNotifierProvider = Provider<LocalNotifier>(
  (_) => MethodChannelLocalNotifier(),
);

abstract class BedtimeStore {
  Future<BedtimeSettings?> load();
  Future<void> save(BedtimeSettings settings);
}

/// `bedtime.json` in the documents folder: `{enabled, sleepMinutes}`.
class FileBedtimeStore implements BedtimeStore {
  Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/bedtime.json');

  @override
  Future<BedtimeSettings?> load() async {
    try {
      final j = jsonDecode(await (await _file).readAsString()) as Map;
      return BedtimeSettings(
        enabled: j['enabled'] == true,
        sleepMinutes: (j['sleepMinutes'] as num?)?.toInt() ?? 480,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(BedtimeSettings settings) async =>
      (await _file).writeAsString(
        jsonEncode({
          'enabled': settings.enabled,
          'sleepMinutes': settings.sleepMinutes,
        }),
      );
}

final bedtimeStoreProvider = Provider<BedtimeStore>((_) => FileBedtimeStore());

class IosBedtime implements BedtimePlatform {
  IosBedtime({
    required this.store,
    required this.notifier,
    required this.alarms,
    this.now = DateTime.now,
  });

  static const prefix = 'bedtime-';

  final BedtimeStore store;
  final LocalNotifier notifier;

  /// The alarms as they are now.
  final Future<List<Alarm>> Function() alarms;
  final DateTime Function() now;

  /// What iOS has now, to leave it alone when nothing changed (null: unknown,
  /// e.g. after a launch or a failure).
  String? _scheduled;
  Future<void> _queue = Future.value();

  Future<BedtimeSettings> _settings() async =>
      await store.load() ?? const BedtimeSettings();

  List<BedtimeReminder> _plan(BedtimeSettings s, List<Alarm> list) =>
      s.enabled ? planBedtimes(list, now(), s.sleepMinutes) : const [];

  BedtimeSettings _with(BedtimeSettings s, List<BedtimeReminder> plan) =>
      BedtimeSettings(
        enabled: s.enabled,
        sleepMinutes: s.sleepMinutes,
        nextAt: plan.isEmpty ? null : plan.first.at,
      );

  /// Runs after earlier calls, so two plans never interleave.
  Future<T> _serial<T>(Future<T> Function() body) {
    final result = _queue.then((_) => body());
    _queue = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  /// Makes iOS's reminders match [plan]; true when something changed.
  Future<bool> _apply(BedtimeSettings s, List<BedtimeReminder> plan) async {
    final key = jsonEncode([
      for (final r in plan) [r.at.millisecondsSinceEpoch, s.sleepMinutes],
    ]);
    if (key == _scheduled) return false;
    _scheduled = null;
    try {
      await notifier.cancelPrefix(prefix);
      for (final r in plan) {
        await notifier.schedule(
          '$prefix${r.at.millisecondsSinceEpoch}',
          r.at,
          'Time for bed',
          bedtimeText(r.alarm, s.sleepMinutes),
        );
      }
      _scheduled = key;
    } catch (_) {
      // No notifications here (or not allowed): the next change tries again.
    }
    return true;
  }

  @override
  Future<BedtimeSettings?> get() async {
    final s = await _settings();
    return _with(s, _plan(s, await alarms()));
  }

  @override
  Future<BedtimeSettings> set(BedtimeSettings settings) => _serial(() async {
    final s = BedtimeSettings(
      enabled: settings.enabled,
      sleepMinutes: settings.sleepMinutes,
    );
    await store.save(s);
    final plan = _plan(s, await alarms());
    await _apply(s, plan);
    return _with(s, plan);
  });

  /// Plans the reminders again for [list] (the alarm list changed); true
  /// when they changed.
  Future<bool> replan(List<Alarm> list) => _serial(() async {
    final s = await _settings();
    return _apply(s, _plan(s, list));
  });
}

final iosBedtimeProvider = Provider<IosBedtime>(
  (ref) => IosBedtime(
    store: ref.watch(bedtimeStoreProvider),
    notifier: ref.watch(localNotifierProvider),
    alarms: () => ref.read(alarmPlatformProvider).list(),
    now: () => ref.read(nowProvider)(),
  ),
);

/// Keep alive (RingLauncher watches it): on iPhone, re-plans the bedtime
/// reminders whenever the alarm list changes, including when it first loads.
final iosBedtimeSyncProvider = Provider<void>((ref) {
  if (!ref.watch(isIosProvider)) return;
  final bedtime = ref.watch(bedtimePlatformProvider);
  if (bedtime is! IosBedtime) return;
  ref.listen(alarmListProvider, (_, next) {
    if (next case AsyncData(:final value)) {
      unawaited(
        bedtime.replan(value).then((changed) {
          if (changed) ref.invalidate(bedtimeProvider);
        }, onError: (Object _) {}),
      );
    }
  }, fireImmediately: true);
});
