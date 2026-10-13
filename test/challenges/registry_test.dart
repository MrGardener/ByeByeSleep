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

  test('resolveStage_missingSetupSubstitutes', () {
    const all = {
      SensorKind.camera,
      SensorKind.accelerometer,
      SensorKind.gyroscope,
    };
    expect(
      resolveStage(
        const StageConfig(ChallengeId.photoMatch, difficulty: 4),
        all,
      ),
      const StageConfig(ChallengeId.brokenCalculator, difficulty: 4),
    );
    const setUp = StageConfig(ChallengeId.nfcTag, params: {'tagId': 'AB12'});
    expect(resolveStage(setUp, const {SensorKind.nfc}), setUp);
  });

  test('maze5_withoutMagnetometer_isLevel3', () {
    expect(
      resolveStage(
        const StageConfig(ChallengeId.tiltMaze, difficulty: 5),
        const {SensorKind.accelerometer, SensorKind.gyroscope},
      ),
      const StageConfig(ChallengeId.tiltMaze, difficulty: 3),
    );
  });

  test('everyNewChallengeHasDefinitionAndRequirements', () {
    expect(definitionFor(ChallengeId.lightsOn).requires(2), {SensorKind.light});
    expect(definitionFor(ChallengeId.walkSteps).requires(2), {
      SensorKind.stepDetector,
    });
    expect(definitionFor(ChallengeId.charger).requires(2), {
      SensorKind.battery,
    });
    expect(definitionFor(ChallengeId.barcode).requires(2), {SensorKind.camera});
    expect(definitionFor(ChallengeId.tiltMaze).requires(5), {
      SensorKind.accelerometer,
      SensorKind.magnetometer,
    });
  });

  test('stairs needs a barometer, otherwise it is replaced', () {
    expect(
      resolveStage(const StageConfig(ChallengeId.stairs), const {}).challenge,
      ChallengeId.brokenCalculator,
    );
    expect(
      resolveStage(const StageConfig(ChallengeId.stairs), const {
        SensorKind.barometer,
      }).challenge,
      ChallengeId.stairs,
    );
  });
}
