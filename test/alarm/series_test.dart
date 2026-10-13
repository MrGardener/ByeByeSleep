import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Alarm main({
    int hour = 17,
    int minute = 0,
    Set<int> days = const {1, 3},
    required SeriesConfig series,
  }) => Alarm(
    id: 4,
    hour: hour,
    minute: minute,
    repeatDays: days,
    label: 'Gym',
    pauseSeconds: 10,
    reminder: const Reminder(caption: 'Keys'),
    series: series,
  );

  List<String> times(List<Alarm> as) => [for (final a in as) a.timeLabel];

  test('after: main is the first, then one every N minutes', () {
    final kids = seriesChildren(
      main(series: const SeriesConfig(count: 5, everyMinutes: 5)),
    );
    expect(times(kids), ['17:05', '17:10', '17:15', '17:20']);
    expect([for (final k in kids) k.id], [401, 402, 403, 404]);
    expect(kids.every((k) => k.parentId == 4 && k.series == null), isTrue);
  });

  test('before: main is the target, the series starts earlier', () {
    final kids = seriesChildren(
      main(
        minute: 20,
        series: const SeriesConfig(
          count: 5,
          everyMinutes: 5,
          direction: SeriesDirection.before,
        ),
      ),
    );
    expect(times(kids), ['17:00', '17:05', '17:10', '17:15']);
  });

  test('children copy label, days, pause and reminder', () {
    final k = seriesChildren(
      main(series: const SeriesConfig(count: 2, everyMinutes: 5)),
    ).single;
    expect(k.label, 'Gym');
    expect(k.repeatDays, {1, 3});
    expect(k.pauseSeconds, 10);
    expect(k.reminder?.caption, 'Keys');
  });

  test('follow-ups: same challenges or one quick challenge', () {
    final same = seriesChildren(
      main(series: const SeriesConfig(count: 2, everyMinutes: 5)),
    ).single;
    expect(same.stages, defaultStages);
    final quick = seriesChildren(
      main(
        series: const SeriesConfig(
          count: 2,
          everyMinutes: 5,
          followUp: FollowUp.quick,
        ),
      ),
    ).single;
    expect(quick.stages, const [
      StageConfig(ChallengeId.brokenCalculator, difficulty: 2),
    ]);
  });

  test('after across midnight moves the repeat days forward', () {
    final kids = seriesChildren(
      main(
        hour: 23,
        minute: 50,
        days: {7, 1}, // Sunday, Monday
        series: const SeriesConfig(count: 3, everyMinutes: 10),
      ),
    );
    expect(times(kids), ['00:00', '00:10']);
    expect(kids.first.repeatDays, {1, 2});
  });

  test('before across midnight moves the repeat days back', () {
    final kids = seriesChildren(
      main(
        hour: 0,
        minute: 5,
        days: {1}, // Monday
        series: const SeriesConfig(
          count: 2,
          everyMinutes: 10,
          direction: SeriesDirection.before,
        ),
      ),
    );
    expect(times(kids), ['23:55']);
    expect(kids.single.repeatDays, {7}); // Sunday
  });

  test('no series means no children', () {
    expect(seriesChildren(Alarm(id: 1, hour: 7, minute: 0)), isEmpty);
  });

  test('extras round-trip through the platform map', () {
    final a = main(series: const SeriesConfig(count: 3, everyMinutes: 7));
    final back = Alarm.fromMap(a.toMap());
    expect(back, a);
    expect(back.series?.count, 3);
    expect(back.reminder?.caption, 'Keys');
    final child = seriesChildren(a).first;
    expect(Alarm.fromMap(child.toMap()).parentId, 4);
  });

  test('an alarm without extras has none', () {
    final m = Alarm(id: 1, hour: 7, minute: 0).toMap()..remove('extras');
    final a = Alarm.fromMap(m);
    expect(a.reminder, isNull);
    expect(a.series, isNull);
    expect(a.parentId, isNull);
  });

  test('reminder-only alarms keep an empty challenge list', () {
    expect(decodeStages(encodeStages(const [])), isEmpty);
    expect(decodeStages(null), defaultStages);
    expect(decodeStages('nonsense'), defaultStages);
  });

  group('one-shot series ring together with their main alarm', () {
    test('saved just after today\'s ring: the whole series is tomorrow', () {
      final kids = seriesChildren(
        Alarm(
          id: 1,
          hour: 7,
          minute: 0,
          series: const SeriesConfig(count: 3, everyMinutes: 5),
        ),
        now: DateTime(2026, 10, 13, 7, 5),
      );
      expect(
        [for (final k in kids) k.onceAt],
        [DateTime(2026, 10, 14, 7, 5), DateTime(2026, 10, 14, 7, 10)],
      );
    });

    test('ending at 07:00, saved at 06:45: earlier ones are today', () {
      final kids = seriesChildren(
        Alarm(
          id: 1,
          hour: 7,
          minute: 0,
          series: const SeriesConfig(
            count: 5,
            everyMinutes: 5,
            direction: SeriesDirection.before,
          ),
        ),
        now: DateTime(2026, 10, 13, 6, 45),
      );
      expect(kids.first.onceAt, DateTime(2026, 10, 13, 6, 40));
      // Already past: it does not ring at all, rather than tomorrow.
      expect(nextRing(kids.first, DateTime(2026, 10, 13, 6, 45)), isNull);
      expect(kids.last.onceAt, DateTime(2026, 10, 13, 6, 55));
    });

    test('repeating series are not pinned to a date', () {
      final kids = seriesChildren(
        Alarm(
          id: 1,
          hour: 7,
          minute: 0,
          repeatDays: {1},
          series: const SeriesConfig(count: 2, everyMinutes: 5),
        ),
        now: DateTime(2026, 10, 13, 7, 5),
      );
      expect(kids.single.onceAt, isNull);
    });

    test('the date survives the platform map', () {
      final a = Alarm(
        id: 2,
        hour: 7,
        minute: 5,
        onceAt: DateTime(2026, 10, 14, 7, 5),
      );
      expect(Alarm.fromMap(a.toMap()).onceAt, a.onceAt);
    });
  });

  test('the awake check setting round-trips and defaults to off', () {
    final a = Alarm(id: 1, hour: 7, minute: 0, followUpMinutes: 15);
    expect(Alarm.fromMap(a.toMap()).followUpMinutes, 15);
    expect(
      Alarm.fromMap(Alarm(id: 1, hour: 7, minute: 0).toMap()).followUpMinutes,
      0,
    );
  });
}
