import 'package:flutter/foundation.dart';

@immutable
class Lap {
  const Lap({required this.number, required this.split, required this.total});

  final int number;

  /// Time since the previous lap.
  final Duration split;

  /// Time since the start.
  final Duration total;

  @override
  bool operator ==(Object other) =>
      other is Lap &&
      other.number == number &&
      other.split == split &&
      other.total == total;

  @override
  int get hashCode => Object.hash(number, split, total);

  @override
  String toString() => 'Lap($number, $split, $total)';
}

/// A stopwatch as plain data: time comes in from outside, so it is exact
/// across pauses and easy to test.
@immutable
class StopwatchState {
  const StopwatchState({
    this.before = Duration.zero,
    this.startedAt,
    this.laps = const [],
  });

  /// Time counted before the current run.
  final Duration before;
  final DateTime? startedAt;

  /// Newest first.
  final List<Lap> laps;

  bool get running => startedAt != null;

  Duration elapsed(DateTime now) =>
      before + (startedAt == null ? Duration.zero : now.difference(startedAt!));

  StopwatchState start(DateTime now) => running
      ? this
      : StopwatchState(before: before, startedAt: now, laps: laps);

  StopwatchState pause(DateTime now) =>
      running ? StopwatchState(before: elapsed(now), laps: laps) : this;

  StopwatchState lap(DateTime now) {
    if (!running) return this;
    final total = elapsed(now);
    final previous = laps.isEmpty ? Duration.zero : laps.first.total;
    return StopwatchState(
      before: before,
      startedAt: startedAt,
      laps: [
        Lap(number: laps.length + 1, split: total - previous, total: total),
        ...laps,
      ],
    );
  }

  StopwatchState reset() => const StopwatchState();

  @override
  bool operator ==(Object other) =>
      other is StopwatchState &&
      other.before == before &&
      other.startedAt == startedAt &&
      listEquals(other.laps, laps);

  @override
  int get hashCode => Object.hash(before, startedAt, Object.hashAll(laps));
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 01:02.34 (minutes:seconds.hundredths), with hours in front once needed.
String formatStopwatch(Duration d) {
  final hundredths = (d.inMilliseconds % 1000) ~/ 10;
  final s = d.inSeconds % 60;
  final m = d.inMinutes % 60;
  final h = d.inHours;
  final head = h > 0 ? '$h:${_two(m)}' : _two(m);
  return '$head:${_two(s)}.${_two(hundredths)}';
}
