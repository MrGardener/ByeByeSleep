import 'package:flutter/foundation.dart';

/// A countdown as plain data. While running only [endsAt] matters, so it
/// keeps time while the app is closed.
@immutable
class TimerState {
  const TimerState({required this.total, this.endsAt, this.pausedLeft});

  factory TimerState.fromJson(Map<String, Object?> j) => TimerState(
    total: Duration(milliseconds: (j['totalMs']! as num).toInt()),
    endsAt: j['endsAtMs'] is num
        ? DateTime.fromMillisecondsSinceEpoch((j['endsAtMs']! as num).toInt())
        : null,
    pausedLeft: j['pausedLeftMs'] is num
        ? Duration(milliseconds: (j['pausedLeftMs']! as num).toInt())
        : null,
  );

  /// The length chosen.
  final Duration total;
  final DateTime? endsAt;

  /// Set while paused part way.
  final Duration? pausedLeft;

  bool get running => endsAt != null;

  Duration remaining(DateTime now) {
    final end = endsAt;
    if (end == null) return pausedLeft ?? total;
    final left = end.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isDone(DateTime now) => running && !now.isBefore(endsAt!);

  TimerState start(DateTime now) {
    if (running) return this;
    final left = pausedLeft ?? total;
    if (left <= Duration.zero) return this;
    return TimerState(total: total, endsAt: now.add(left));
  }

  TimerState pause(DateTime now) =>
      running ? TimerState(total: total, pausedLeft: remaining(now)) : this;

  TimerState addMinute() => running
      ? TimerState(
          total: total,
          endsAt: endsAt!.add(const Duration(minutes: 1)),
        )
      : TimerState(
          total: total,
          pausedLeft: (pausedLeft ?? total) + const Duration(minutes: 1),
        );

  TimerState reset() => TimerState(total: total);

  Map<String, Object?> toJson() => {
    'totalMs': total.inMilliseconds,
    if (endsAt != null) 'endsAtMs': endsAt!.millisecondsSinceEpoch,
    if (pausedLeft != null) 'pausedLeftMs': pausedLeft!.inMilliseconds,
  };

  @override
  bool operator ==(Object other) =>
      other is TimerState &&
      other.total == total &&
      other.endsAt == endsAt &&
      other.pausedLeft == pausedLeft;

  @override
  int get hashCode => Object.hash(total, endsAt, pausedLeft);
}

String _two(int n) => n.toString().padLeft(2, '0');

/// 04:05, or 1:02:03 with hours. Whole seconds, rounded up, so it never
/// shows 00:00 before the time is up.
String formatTimer(Duration d) {
  final secs = (d.inMilliseconds + 999) ~/ 1000;
  final h = secs ~/ 3600, m = secs % 3600 ~/ 60, s = secs % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
}
