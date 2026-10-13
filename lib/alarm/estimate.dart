/// How long it usually takes to turn an alarm off: a rough range from typical
/// times per challenge, so the owner can see the cost of a setup. Pure Dart.
library;

import '../challenges/core/challenge_id.dart';
import 'stage_config.dart';

/// Seconds a wide-awake to a sleepy person takes at difficulty 3.
const _typical = <ChallengeId, (int, int)>{
  ChallengeId.orientationHopscotch: (15, 45),
  ChallengeId.tiltMaze: (20, 90),
  ChallengeId.brokenCalculator: (15, 60),
  ChallengeId.stroopTap: (15, 40),
  ChallengeId.lightsOn: (5, 30),
  ChallengeId.walkSteps: (20, 60), // replaced by the step count when set
  ChallengeId.photoMatch: (20, 90),
  ChallengeId.nfcTag: (15, 60),
  ChallengeId.barcode: (15, 60),
  ChallengeId.charger: (15, 60),
  ChallengeId.heartRate: (60, 180),
  ChallengeId.compass: (20, 90),
  ChallengeId.watchSwing: (20, 60),
  ChallengeId.watchSteps: (30, 120),
  ChallengeId.stairs: (40, 150),
};

/// Challenges whose difficulty changes how long they take.
const _scaled = {
  ChallengeId.orientationHopscotch,
  ChallengeId.tiltMaze,
  ChallengeId.brokenCalculator,
  ChallengeId.stroopTap,
};

({Duration low, Duration high}) estimateStop(
  List<StageConfig> stages,
  int pauseSeconds,
) {
  var low = 0.0, high = 0.0;
  for (final s in stages) {
    var (l, h) = _typical[s.challenge]!;
    final steps = (s.params['steps'] as num?)?.toDouble();
    if (s.challenge == ChallengeId.walkSteps && steps != null) {
      // About 0.6–1.2 s per step plus finding the phone's rhythm.
      l = (steps * 0.6).round() + 10;
      h = (steps * 1.2).round() + 30;
    }
    final factor = _scaled.contains(s.challenge)
        ? 0.55 + 0.15 * s.difficulty
        : 1;
    low += l * factor;
    high += h * factor;
  }
  final pauses = stages.isEmpty ? 0 : (stages.length - 1) * pauseSeconds;
  return (
    low: Duration(seconds: low.round() + pauses),
    high: Duration(seconds: high.round() + pauses),
  );
}

String estimateLabel(List<StageConfig> stages, [int pauseSeconds = 0]) {
  if (stages.isEmpty) return 'Stops at once';
  final e = estimateStop(stages, pauseSeconds);
  if (e.high < const Duration(minutes: 1)) return 'Under a minute to turn off';
  final low = (e.low.inSeconds / 60).floor().clamp(1, 999);
  final high = (e.high.inSeconds / 60).ceil();
  return low >= high
      ? 'About $high min to turn off'
      : 'About $low–$high min to turn off';
}
