import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/ringing/stage_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  const calc = StageConfig(ChallengeId.brokenCalculator, difficulty: 3);
  const stroop = StageConfig(ChallengeId.stroopTap);

  StageEngine engine(
    List<StageConfig> stages, {
    Duration ago = Duration.zero,
    int startIndex = 0,
  }) => StageEngine(
    stages: stages,
    ringStartedAt: now.subtract(ago),
    startIndex: startIndex,
    clock: () => now,
  );

  setUp(() => now = DateTime(2026, 10, 12, 7));

  test('engine_runsStagesWithBreathers', () {
    final e = engine([calc, stroop]);
    expect(e.phase, isA<Running>().having((r) => r.index, 'index', 0));
    expect(e.ringLevel, 1.0);
    e.stagePassed();
    expect(
      e.phase,
      isA<Breather>()
          .having((b) => b.nextIndex, 'next', 1)
          .having((b) => b.remaining, 'remaining', const Duration(seconds: 20)),
    );
    expect(e.ringLevel, 0.2);
    now = now.add(const Duration(seconds: 19));
    e.tick();
    expect(e.phase, isA<Breather>());
    now = now.add(const Duration(seconds: 1));
    e.tick();
    expect(
      e.phase,
      isA<Running>()
          .having((r) => r.index, 'index', 1)
          .having((r) => r.stage, 'stage', stroop),
    );
    expect(e.ringLevel, 1.0);
    expect(e.currentIndex, 1);
    e.stagePassed();
    expect(e.phase, isA<Done>());
  });

  test('engine_singleStage_passGoesStraightToDone', () {
    final e = engine([calc])..stagePassed();
    expect(e.phase, isA<Done>());
    expect(e.currentIndex, 1);
  });

  test('engine_noStages_isDone', () {
    expect(engine(const []).phase, isA<Done>());
  });

  test('engine_hintAndFallbackTimes', () {
    final e = engine([calc, stroop]);
    Running r() => e.phase as Running;
    now = now.add(const Duration(minutes: 1, seconds: 59));
    expect(r().hintVisible, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(r().hintVisible, isTrue);
    now = now.add(const Duration(minutes: 2, seconds: 59));
    expect(r().fallbackAvailable, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(r().fallbackAvailable, isTrue);
    e.useFallback(ChallengeId.stroopTap);
    expect(r().stage, const StageConfig(ChallengeId.stroopTap, difficulty: 3));
    expect(r().hintVisible, isFalse);
    expect(r().fallbackAvailable, isFalse);
  });

  test('stage timer restarts for each stage', () {
    final e = engine([calc, stroop]);
    now = now.add(const Duration(minutes: 4));
    e.stagePassed();
    now = now.add(const Duration(seconds: 20));
    e.tick();
    expect((e.phase as Running).hintVisible, isFalse);
  });

  test('engine_safetyExitAfter15Minutes', () {
    final e = engine([calc], ago: const Duration(minutes: 14, seconds: 59));
    expect(e.safetyExitAvailable, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(e.safetyExitAvailable, isTrue);
  });

  test('engine_resumesFromSavedProgress', () {
    final e = engine(
      [calc, calc, stroop],
      startIndex: 2,
      ago: const Duration(minutes: 10),
    );
    expect(e.phase, isA<Running>().having((r) => r.index, 'index', 2));
    expect(e.safetyExitAvailable, isFalse);
    now = now.add(const Duration(minutes: 5));
    expect(e.safetyExitAvailable, isTrue);
  });

  test('saved progress past the last stage is Done', () {
    expect(engine([calc], startIndex: 1).phase, isA<Done>());
  });
}
