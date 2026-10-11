import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const accelOnly = {SensorKind.accelerometer};

  test('registry_substitutesWhenSensorMissing', () {
    expect(
      resolveStage(
        const StageConfig(ChallengeId.tiltMaze, difficulty: 4),
        accelOnly,
      ),
      const StageConfig(ChallengeId.tiltMaze, difficulty: 3),
    );
    expect(
      resolveStage(
        const StageConfig(ChallengeId.orientationHopscotch),
        const {},
      ),
      const StageConfig(ChallengeId.brokenCalculator),
    );
    expect(
      resolveStage(
        const StageConfig(ChallengeId.tiltMaze, difficulty: 3),
        const {},
      ),
      const StageConfig(ChallengeId.brokenCalculator, difficulty: 3),
    );
    expect(
      resolveStage(
        const StageConfig(ChallengeId.tiltMaze, difficulty: 1),
        const {},
      ),
      const StageConfig(ChallengeId.tiltMaze, difficulty: 1),
    );
    const calc = StageConfig(ChallengeId.brokenCalculator, difficulty: 5);
    expect(resolveStage(calc, const {}), calc);
  });

  test('fallbackFor_neverReturnsSameChallenge', () {
    for (final id in ChallengeId.values) {
      expect(fallbackFor(id), isNot(id));
    }
  });

  test('every challenge has a definition with a title', () {
    for (final id in ChallengeId.values) {
      expect(definitionFor(id).id, id);
      expect(definitionFor(id).title, isNotEmpty);
    }
  });
}
