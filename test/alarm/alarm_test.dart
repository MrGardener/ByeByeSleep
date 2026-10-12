import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toMap/fromMap round-trips', () {
    final a = Alarm(
      id: 3,
      hour: 7,
      minute: 5,
      repeatDays: {5, 1},
      label: 'Work',
    );
    expect(Alarm.fromMap(a.toMap()), a);
    expect(a.toMap()['repeatDays'], [1, 5]);
  });

  test('timeLabel is zero padded', () {
    expect(Alarm(id: 1, hour: 7, minute: 5).timeLabel, '07:05');
  });

  test('isRepeating', () {
    expect(Alarm(id: 1, hour: 7, minute: 0).isRepeating, isFalse);
    expect(
      Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1}).isRepeating,
      isTrue,
    );
  });

  test('constructor rejects invalid values', () {
    expect(
      () => Alarm(id: 1, hour: 24, minute: 0),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => Alarm(id: 1, hour: 7, minute: 0, repeatDays: {0}),
      throwsA(isA<AssertionError>()),
    );
  });

  test('copyWith replaces only given fields', () {
    final a = Alarm(id: 1, hour: 7, minute: 0, label: 'x');
    final b = a.copyWith(enabled: false);
    expect(b.enabled, isFalse);
    expect(b.label, 'x');
    expect(b.id, 1);
  });

  test('stages_roundTripThroughMap', () {
    final a = Alarm(
      id: 1,
      hour: 7,
      minute: 0,
      stages: const [StageConfig(ChallengeId.brokenCalculator, difficulty: 5)],
    );
    expect(Alarm.fromMap(a.toMap()), a);
    expect(a.toMap()['stages'], isA<String>());
  });

  test('fromMap_missingStages_usesDefault', () {
    final a = Alarm.fromMap({'id': 1, 'hour': 7, 'minute': 0});
    expect(a.stages, defaultStages);
  });
}
