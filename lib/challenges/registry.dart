import 'package:flutter/widgets.dart';

import '../alarm/stage_config.dart';
import 'broken_calculator/widget.dart';
import 'core/challenge.dart';
import 'core/challenge_id.dart';
import 'core/types.dart';
import 'orientation_hopscotch/widget.dart';
import 'stroop_tap/widget.dart';

Widget _placeholder(ChallengeArgs args) => const Center(child: Text('…'));

final Map<ChallengeId, ChallengeDefinition> _definitions = {
  ChallengeId.orientationHopscotch: ChallengeDefinition(
    id: ChallengeId.orientationHopscotch,
    title: 'Orientation hopscotch',
    instructions: 'Turn the phone into each position shown, in order.',
    requires: (_) => const {SensorKind.accelerometer},
    build: (args) => HopscotchChallenge(args: args),
  ),
  ChallengeId.tiltMaze: ChallengeDefinition(
    id: ChallengeId.tiltMaze,
    title: 'Tilt maze',
    instructions: 'Guide the ball to the glowing exit.',
    requires: (d) => switch (d) {
      1 => const <SensorKind>{},
      2 || 3 => const {SensorKind.accelerometer},
      _ => const {SensorKind.accelerometer, SensorKind.gyroscope},
    },
    build: _placeholder,
  ),
  ChallengeId.brokenCalculator: ChallengeDefinition(
    id: ChallengeId.brokenCalculator,
    title: 'Broken calculator',
    instructions: 'Solve the sum. The keys move after every press.',
    requires: (_) => const {},
    build: (args) => BrokenCalculatorChallenge(args: args),
  ),
  ChallengeId.stroopTap: ChallengeDefinition(
    id: ChallengeId.stroopTap,
    title: 'Colour words',
    instructions: 'Tap the colour of the ink, not the word.',
    requires: (_) => const {},
    build: (args) => StroopChallenge(args: args),
  ),
};

ChallengeDefinition definitionFor(ChallengeId id) => _definitions[id]!;

/// The stage to actually run given the sensors this device has (spec §6.2).
StageConfig resolveStage(StageConfig s, Set<SensorKind> available) {
  bool ok(int d) =>
      available.containsAll(definitionFor(s.challenge).requires(d));
  if (ok(s.difficulty)) return s;
  // The rotating maze (level 4) needs a gyroscope; drop to the tilt-only level.
  if (s.challenge == ChallengeId.tiltMaze && s.difficulty == 4 && ok(3)) {
    return s.copyWith(difficulty: 3);
  }
  return s.copyWith(challenge: ChallengeId.brokenCalculator);
}

/// Replacement offered after a stage has run too long (spec §6.3).
ChallengeId fallbackFor(ChallengeId current) =>
    current == ChallengeId.brokenCalculator
    ? ChallengeId.stroopTap
    : ChallengeId.brokenCalculator;
