import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../alarm/guard.dart';
import 'timer_state.dart';

/// Rings when a timer ends, also with the app closed (TimerBell.kt).
abstract class TimerBell {
  Future<void> schedule(int id, DateTime at, String label);

  /// Cancels a pending timer and silences one that is ringing.
  Future<void> cancel(int id);
}

class MethodChannelTimerBell implements TimerBell {
  static const _channel = MethodChannel('byebyesleep/timer');

  Future<void> _call(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // No native timer here (iPhone for now): the screen still counts down.
    }
  }

  @override
  Future<void> schedule(int id, DateTime at, String label) => _call(
    'schedule',
    {'id': id, 'atMs': at.millisecondsSinceEpoch, 'label': label},
  );

  @override
  Future<void> cancel(int id) => _call('cancel', {'id': id});
}

final timerBellProvider = Provider<TimerBell>((_) => MethodChannelTimerBell());

class TimerEntry {
  const TimerEntry({required this.id, required this.state, this.name = ''});

  final int id;
  final TimerState state;

  /// Optional, e.g. "Pasta".
  final String name;

  /// Shown on the card and in the "Time's up" notification.
  String get label => name.isEmpty ? 'Timer ${formatTimer(state.total)}' : name;

  TimerEntry copyWith(TimerState state) =>
      TimerEntry(id: id, state: state, name: name);

  TimerEntry renamed(String name) =>
      TimerEntry(id: id, state: state, name: name);
}

/// Every timer, plus the length picked for the next one.
class TimersState {
  const TimersState({
    this.timers = const [],
    this.nextId = 1,
    this.composer = const Duration(minutes: 5),
  });

  factory TimersState.fromJson(Map<String, Object?> j) => TimersState(
    timers: [
      for (final t in (j['timers'] as List? ?? const []))
        TimerEntry(
          id: ((t as Map)['id']! as num).toInt(),
          state: TimerState.fromJson(t.cast<String, Object?>()),
          name: t['name'] as String? ?? '',
        ),
    ],
    nextId: (j['nextId'] as num?)?.toInt() ?? 1,
    composer: Duration(
      milliseconds: (j['composerMs'] as num?)?.toInt() ?? 300000,
    ),
  );

  final List<TimerEntry> timers;
  final int nextId;
  final Duration composer;

  Map<String, Object?> toJson() => {
    'timers': [
      for (final t in timers) {'id': t.id, 'name': t.name, ...t.state.toJson()},
    ],
    'nextId': nextId,
    'composerMs': composer.inMilliseconds,
  };

  TimersState copyWith({
    List<TimerEntry>? timers,
    int? nextId,
    Duration? composer,
  }) => TimersState(
    timers: timers ?? this.timers,
    nextId: nextId ?? this.nextId,
    composer: composer ?? this.composer,
  );
}

abstract class TimerStore {
  Future<TimersState?> load();
  Future<void> save(TimersState state);
}

/// `timers.json` in the documents folder.
class FileTimerStore implements TimerStore {
  Future<File> get _file async =>
      File('${(await getApplicationDocumentsDirectory()).path}/timers.json');

  @override
  Future<TimersState?> load() async {
    try {
      final j = jsonDecode(await (await _file).readAsString());
      return TimersState.fromJson((j as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(TimersState state) async =>
      (await _file).writeAsString(jsonEncode(state.toJson()));
}

final timerStoreProvider = Provider<TimerStore>((_) => FileTimerStore());

class TimersNotifier extends AsyncNotifier<TimersState> {
  DateTime _now() => ref.read(nowProvider)();
  TimerBell get _bell => ref.read(timerBellProvider);
  TimersState get _state => state.value ?? const TimersState();

  @override
  Future<TimersState> build() async =>
      await ref.read(timerStoreProvider).load() ?? const TimersState();

  Future<void> _set(TimersState next) async {
    state = AsyncData(next);
    await ref.read(timerStoreProvider).save(next);
  }

  TimerEntry? _find(int id) {
    for (final t in _state.timers) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _replace(TimerEntry entry) => _set(
    _state.copyWith(
      timers: [for (final t in _state.timers) t.id == entry.id ? entry : t],
    ),
  );

  Future<void> choose(Duration length) =>
      _set(_state.copyWith(composer: length));

  /// Starts a new timer of the chosen length.
  Future<void> add({String name = ''}) async {
    final s = _state;
    if (s.composer <= Duration.zero) return;
    final entry = TimerEntry(
      id: s.nextId,
      state: TimerState(total: s.composer).start(_now()),
      name: name.trim(),
    );
    await _bell.schedule(entry.id, entry.state.endsAt!, entry.label);
    await _set(s.copyWith(timers: [...s.timers, entry], nextId: s.nextId + 1));
  }

  Future<void> toggle(int id) async {
    final t = _find(id);
    if (t == null) return;
    if (t.state.running) {
      await _bell.cancel(id);
      await _replace(t.copyWith(t.state.pause(_now())));
    } else {
      final started = t.state.start(_now());
      if (!started.running) return;
      await _bell.schedule(id, started.endsAt!, t.label);
      await _replace(t.copyWith(started));
    }
  }

  Future<void> addMinute(int id) async {
    final t = _find(id);
    if (t == null) return;
    final next = t.copyWith(t.state.addMinute());
    if (next.state.running) {
      await _bell.schedule(id, next.state.endsAt!, next.label);
    }
    await _replace(next);
  }

  Future<void> rename(int id, String name) async {
    final t = _find(id);
    if (t == null) return;
    final next = t.renamed(name.trim());
    if (next.state.running) {
      await _bell.schedule(id, next.state.endsAt!, next.label);
    }
    await _replace(next);
  }

  /// Delete, or Stop once the time is up.
  Future<void> remove(int id) async {
    await _bell.cancel(id);
    await _set(
      _state.copyWith(
        timers: [
          for (final t in _state.timers)
            if (t.id != id) t,
        ],
      ),
    );
  }
}

final timersProvider = AsyncNotifierProvider<TimersNotifier, TimersState>(
  TimersNotifier.new,
);
