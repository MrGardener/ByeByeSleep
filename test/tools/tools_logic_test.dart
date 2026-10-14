import 'package:byebyesleep/tools/stopwatch_state.dart';
import 'package:byebyesleep/tools/timer_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 10, 14, 9);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  group('stopwatch', () {
    test('runs, pauses and resumes', () {
      var s = const StopwatchState();
      expect(s.elapsed(t0), Duration.zero);
      s = s.start(t0);
      expect(s.running, isTrue);
      expect(s.elapsed(at(1500)), const Duration(milliseconds: 1500));
      s = s.pause(at(2000));
      expect(s.elapsed(at(9000)), const Duration(seconds: 2));
      s = s.start(at(10000));
      expect(s.elapsed(at(11000)), const Duration(seconds: 3));
    });

    test('laps record each split, newest first', () {
      var s = const StopwatchState().start(t0);
      s = s.lap(at(1000)).lap(at(3500));
      expect(s.laps, [
        const Lap(
          number: 2,
          split: Duration(milliseconds: 2500),
          total: Duration(milliseconds: 3500),
        ),
        const Lap(
          number: 1,
          split: Duration(seconds: 1),
          total: Duration(seconds: 1),
        ),
      ]);
    });

    test('lap only while running; reset clears everything', () {
      var s = const StopwatchState();
      expect(s.lap(t0).laps, isEmpty);
      s = s.start(t0).lap(at(1000)).pause(at(2000)).reset();
      expect(s, const StopwatchState());
    });

    test('formats like a stopwatch', () {
      expect(
        formatStopwatch(
          const Duration(minutes: 1, seconds: 2, milliseconds: 345),
        ),
        '01:02.34',
      );
      expect(
        formatStopwatch(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03.00',
      );
    });
  });

  group('timer', () {
    test('counts down and finishes', () {
      var t = const TimerState(total: Duration(minutes: 5));
      expect(t.remaining(t0), const Duration(minutes: 5));
      t = t.start(t0);
      expect(t.endsAt, at(300000));
      expect(t.remaining(at(60000)), const Duration(minutes: 4));
      expect(t.isDone(at(299999)), isFalse);
      expect(t.isDone(at(300000)), isTrue);
      expect(t.remaining(at(400000)), Duration.zero);
    });

    test('pause keeps the remaining time; resume continues from it', () {
      var t = const TimerState(total: Duration(minutes: 1)).start(t0);
      t = t.pause(at(20000));
      expect(t.running, isFalse);
      expect(t.remaining(at(90000)), const Duration(seconds: 40));
      t = t.start(at(100000));
      expect(t.endsAt, at(140000));
    });

    test('add a minute while running moves the end', () {
      final t = const TimerState(total: Duration(minutes: 1))
          .start(t0)
          .addMinute();
      expect(t.endsAt, at(120000));
    });

    test('reset goes back to the chosen length; zero cannot start', () {
      final t = const TimerState(total: Duration(minutes: 2)).start(t0).reset();
      expect(t, const TimerState(total: Duration(minutes: 2)));
      expect(const TimerState(total: Duration.zero).start(t0).running, isFalse);
    });

    test('survives a restart (json)', () {
      final t = const TimerState(total: Duration(minutes: 3)).start(t0);
      expect(TimerState.fromJson(t.toJson()), t);
      final p = t.pause(at(1000));
      expect(TimerState.fromJson(p.toJson()), p);
    });

    test('formats hours only when needed', () {
      expect(formatTimer(const Duration(minutes: 4, seconds: 5)), '04:05');
      expect(
        formatTimer(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      // Rounds up: 0.2 s left still shows 00:01.
      expect(formatTimer(const Duration(milliseconds: 200)), '00:01');
    });
  });
}
