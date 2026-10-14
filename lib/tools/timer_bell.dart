import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../alarm/guard.dart';
import 'timer_state.dart';

/// Rings when a timer ends, also with the app closed (TimerBell.kt).
abstract class TimerBell {
  Future<void> schedule(DateTime at, String label);

  /// Cancels a pending timer and silences one that is ringing.
  Future<void> cancel();
}

class MethodChannelTimerBell implements TimerBell {
  static const _channel = MethodChannel('byebyesleep/timer');

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // No native timer here (iPhone for now): the screen still counts down.
    }
  }

  @override
  Future<void> schedule(DateTime at, String label) =>
      _call('schedule', {'atMs': at.millisecondsSinceEpoch, 'label': label});

  @override
  Future<void> cancel() => _call('cancel');
}

final timerBellProvider = Provider<TimerBell>((_) => MethodChannelTimerBell());

abstract class TimerStore {
  Future<TimerState?> load();
  Future<void> save(TimerState state);
}

/// `timer.json` in the documents folder.
class FileTimerStore implements TimerStore {
  Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/timer.json');

  @override
  Future<TimerState?> load() async {
    try {
      final j = jsonDecode(await (await _file).readAsString());
      return TimerState.fromJson((j as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(TimerState state) async =>
      (await _file).writeAsString(jsonEncode(state.toJson()));
}

final timerStoreProvider = Provider<TimerStore>((_) => FileTimerStore());

const defaultTimer = TimerState(total: Duration(minutes: 5));

class TimerNotifier extends AsyncNotifier<TimerState> {
  DateTime _now() => ref.read(nowProvider)();
  TimerBell get _bell => ref.read(timerBellProvider);

  @override
  Future<TimerState> build() async =>
      await ref.read(timerStoreProvider).load() ?? defaultTimer;

  Future<void> _set(TimerState next) async {
    state = AsyncData(next);
    await ref.read(timerStoreProvider).save(next);
  }

  Future<void> choose(Duration total) async {
    await _bell.cancel();
    await _set(TimerState(total: total));
  }

  Future<void> startOrPause() async {
    final t = await future;
    if (t.running) {
      await _bell.cancel();
      await _set(t.pause(_now()));
    } else {
      final started = t.start(_now());
      if (!started.running) return;
      await _bell.schedule(started.endsAt!, 'Timer ${formatTimer(t.total)}');
      await _set(started);
    }
  }

  Future<void> addMinute() async {
    final t = (await future).addMinute();
    if (t.running) {
      await _bell.schedule(t.endsAt!, 'Timer ${formatTimer(t.total)}');
    }
    await _set(t);
  }

  /// Reset, or Stop once the time is up.
  Future<void> reset() async {
    await _bell.cancel();
    await _set((await future).reset());
  }
}

final timerProvider = AsyncNotifierProvider<TimerNotifier, TimerState>(
  TimerNotifier.new,
);
