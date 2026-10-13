import 'package:byebyesleep/alarm/estimate.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default stages give a range of a few minutes', () {
    final e = estimateStop(defaultStages, 0);
    expect(e.low, greaterThanOrEqualTo(const Duration(seconds: 30)));
    expect(e.high, lessThanOrEqualTo(const Duration(minutes: 8)));
    expect(e.high, greaterThan(e.low));
  });

  test('a pause adds (stages − 1) × pause to both ends', () {
    final none = estimateStop(defaultStages, 0);
    final paused = estimateStop(defaultStages, 20);
    expect(paused.low - none.low, const Duration(seconds: 60));
    expect(paused.high - none.high, const Duration(seconds: 60));
  });

  test('harder challenges take longer', () {
    final easy = estimateStop(const [
      StageConfig(ChallengeId.tiltMaze, difficulty: 1),
    ], 0);
    final hard = estimateStop(const [
      StageConfig(ChallengeId.tiltMaze, difficulty: 5),
    ], 0);
    expect(hard.high, greaterThan(easy.high));
  });

  test('a longer walk takes longer', () {
    Duration walk(int steps) => estimateStop([
      StageConfig(ChallengeId.walkSteps, params: {'steps': steps}),
    ], 0).high;
    expect(walk(200), greaterThan(walk(20)));
  });

  test('labels', () {
    expect(estimateLabel(const []), 'Stops at once');
    expect(
      estimateLabel(const [StageConfig(ChallengeId.lightsOn)]),
      'Under a minute to turn off',
    );
    expect(
      estimateLabel(defaultStages),
      matches(r'^About \d+–\d+ min to turn off$'),
    );
  });
}
