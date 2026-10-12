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
    this.params = const {},
    this.onUnavailable,
  });

  /// Called when the challenge cannot run right now (camera failed, no
  /// permission, sensor broken); the ring screen swaps in a fallback at once.
  final VoidCallback? onUnavailable;

  final int difficulty;

  /// The stage's setup data (see each challenge's setup screen).
  final Map<String, Object?> params;
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
    this.isSetUp = _alwaysSetUp,
    this.setup,
  });

  static bool _alwaysSetUp(Map<String, Object?> params) => true;

  final ChallengeId id;
  final String title;
  final String instructions;
  final Set<SensorKind> Function(int difficulty) requires;
  final Widget Function(ChallengeArgs args) build;

  /// Whether [params] hold everything the challenge needs to run.
  final bool Function(Map<String, Object?> params) isSetUp;

  /// Opens the setup screen; resolves to new params, or null if cancelled.
  /// Null when the challenge needs no setup.
  final Future<Map<String, Object?>?> Function(
    BuildContext context,
    Map<String, Object?> current,
  )?
  setup;
}
