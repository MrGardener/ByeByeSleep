import 'dart:io';

import '../alarm/stage_config.dart';
import 'barcode/setup.dart';
import 'barcode/widget.dart';
import 'broken_calculator/widget.dart';
import 'charger/widget.dart';
import 'core/challenge.dart';
import 'core/challenge_id.dart';
import 'core/types.dart';
import 'photo_match/setup.dart';
import 'photo_match/widget.dart';
import 'lights_on/setup.dart';
import 'lights_on/widget.dart';
import 'nfc_tag/setup.dart';
import 'nfc_tag/widget.dart';
import 'orientation_hopscotch/widget.dart';
import 'stroop_tap/widget.dart';
import 'tilt_maze/widget.dart';
import 'walk_steps/setup.dart';
import 'walk_steps/widget.dart';

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
      4 => const {SensorKind.accelerometer, SensorKind.gyroscope},
      _ => const {SensorKind.accelerometer, SensorKind.magnetometer},
    },
    build: (args) => TiltMazeChallenge(args: args),
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
  ChallengeId.lightsOn: ChallengeDefinition(
    id: ChallengeId.lightsOn,
    title: 'Lights on',
    instructions: 'Switch on the room light.',
    requires: (_) => const {SensorKind.light},
    build: (args) => LightsChallenge(args: args),
    setup: setupLights,
  ),
  ChallengeId.walkSteps: ChallengeDefinition(
    id: ChallengeId.walkSteps,
    title: 'Walk',
    instructions: 'Walk to your spot.',
    requires: (_) => const {SensorKind.stepDetector},
    build: (args) => WalkChallenge(args: args),
    setup: setupWalk,
  ),
  ChallengeId.photoMatch: ChallengeDefinition(
    id: ChallengeId.photoMatch,
    title: 'Photo match',
    instructions: 'Take the same photo as your reference.',
    requires: (_) => const {SensorKind.camera},
    build: (args) => PhotoMatchChallenge(args: args),
    setup: setupPhoto,
    isSetUp: (p) {
      final photos = p['photos'];
      return photos is List &&
          photos.length == 2 &&
          photos.every((path) => path is String && File(path).existsSync());
    },
  ),
  ChallengeId.nfcTag: ChallengeDefinition(
    id: ChallengeId.nfcTag,
    title: 'NFC sticker',
    instructions: 'Touch the back of the phone to your sticker.',
    requires: (_) => const {SensorKind.nfc},
    build: (args) => NfcChallenge(args: args),
    setup: setupNfc,
    isSetUp: (p) => (p['tagId'] as String?)?.isNotEmpty ?? false,
  ),
  ChallengeId.barcode: ChallengeDefinition(
    id: ChallengeId.barcode,
    title: 'Barcode',
    instructions: 'Scan your registered barcode.',
    requires: (_) => const {SensorKind.camera},
    build: (args) => BarcodeChallenge(args: args),
    setup: setupBarcode,
    isSetUp: (p) => (p['code'] as String?)?.isNotEmpty ?? false,
  ),
  ChallengeId.charger: ChallengeDefinition(
    id: ChallengeId.charger,
    title: 'Charger',
    instructions: 'Plug the phone into a charger away from your bed.',
    requires: (_) => const {SensorKind.battery},
    build: (args) => ChargerChallenge(args: args),
  ),
};

ChallengeDefinition definitionFor(ChallengeId id) => _definitions[id]!;

/// The stage to actually run given the sensors this device has (spec §6.2).
StageConfig resolveStage(StageConfig s, Set<SensorKind> available) {
  final fallback = StageConfig(
    ChallengeId.brokenCalculator,
    difficulty: s.difficulty,
  );
  if (!definitionFor(s.challenge).isSetUp(s.params)) return fallback;
  bool ok(int d) =>
      available.containsAll(definitionFor(s.challenge).requires(d));
  if (ok(s.difficulty)) return s;
  // Levels 4–5 need a gyroscope / magnetometer; drop to the tilt-only level.
  if (s.challenge == ChallengeId.tiltMaze && s.difficulty >= 4 && ok(3)) {
    return s.copyWith(difficulty: 3);
  }
  return fallback;
}

/// Replacement offered after a stage has run too long (spec §6.3).
ChallengeId fallbackFor(ChallengeId current) =>
    current == ChallengeId.brokenCalculator
    ? ChallengeId.stroopTap
    : ChallengeId.brokenCalculator;
