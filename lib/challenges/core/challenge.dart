import 'dart:math';

import 'package:flutter/widgets.dart';

import 'challenge_id.dart';
import 'types.dart';

/// What a challenge widget gets from the ring screen (or practice mode).
class ChallengeArgs {
  const ChallengeArgs({
    required this.difficulty,
    required this.random,
    required this.onPassed,
  });

  final int difficulty;
  final Random random;
  final VoidCallback onPassed;
}

class ChallengeDefinition {
  const ChallengeDefinition({
    required this.id,
    required this.title,
    required this.instructions,
    required this.requires,
    required this.build,
  });

  final ChallengeId id;
  final String title;
  final String instructions;
  final Set<SensorKind> Function(int difficulty) requires;
  final Widget Function(ChallengeArgs args) build;
}
