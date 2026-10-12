import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encode/decode round-trips', () {
    const stages = [
      StageConfig(ChallengeId.tiltMaze, difficulty: 4),
      StageConfig(ChallengeId.stroopTap, difficulty: 1, params: {'x': 1}),
    ];
    expect(decodeStages(encodeStages(stages)), stages);
  });

  test('decodeStages_unknownChallengeDropped', () {
    expect(
      decodeStages(
        '[{"challenge":"teleport"},{"challenge":"stroopTap","difficulty":4}]',
      ),
      [const StageConfig(ChallengeId.stroopTap, difficulty: 4)],
    );
  });

  test('decodeStages_invalidJson_usesDefault', () {
    expect(decodeStages('not json'), defaultStages);
    expect(decodeStages(null), defaultStages);
    expect(decodeStages(''), defaultStages);
    expect(decodeStages('[{"challenge":"teleport"}]'), defaultStages);
  });

  test('difficulty is clamped to 1..5', () {
    expect(
      decodeStages('[{"challenge":"tiltMaze","difficulty":9}]')
          .single
          .difficulty,
      5,
    );
  });

  test('default stages are the four planned challenges at difficulty 2', () {
    expect(defaultStages.map((s) => s.challenge), [
      ChallengeId.orientationHopscotch,
      ChallengeId.tiltMaze,
      ChallengeId.brokenCalculator,
      ChallengeId.stroopTap,
    ]);
    expect(defaultStages.every((s) => s.difficulty == 2), isTrue);
  });
}
