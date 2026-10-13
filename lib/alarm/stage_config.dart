import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../challenges/core/challenge_id.dart';

/// One stage of a ringing alarm: which challenge, how hard, and its setup.
@immutable
class StageConfig {
  const StageConfig(
    this.challenge, {
    this.difficulty = 2,
    this.params = const {},
  });

  factory StageConfig.fromJson(Map<String, Object?> j) => StageConfig(
    switch (j['challenge']! as String) {
      'charger' => ChallengeId.batteryGuess, // retired challenge
      final name => ChallengeId.values.byName(name),
    },
    difficulty: ((j['difficulty'] as num?)?.toInt() ?? 2).clamp(1, 5),
    params: (j['params'] as Map<String, Object?>?) ?? const {},
  );

  final ChallengeId challenge;
  final int difficulty;
  final Map<String, Object?> params;

  StageConfig copyWith({
    ChallengeId? challenge,
    int? difficulty,
    Map<String, Object?>? params,
  }) => StageConfig(
    challenge ?? this.challenge,
    difficulty: difficulty ?? this.difficulty,
    params: params ?? this.params,
  );

  Map<String, Object?> toJson() => {
    'challenge': challenge.name,
    'difficulty': difficulty,
    if (params.isNotEmpty) 'params': params,
  };

  @override
  bool operator ==(Object other) =>
      other is StageConfig &&
      other.challenge == challenge &&
      other.difficulty == difficulty &&
      mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(challenge, difficulty, params.length);

  @override
  String toString() => 'StageConfig(${challenge.name}, d$difficulty)';
}

const List<StageConfig> defaultStages = [
  StageConfig(ChallengeId.orientationHopscotch),
  StageConfig(ChallengeId.tiltMaze),
  StageConfig(ChallengeId.brokenCalculator),
  StageConfig(ChallengeId.stroopTap),
];

/// The full routine from spec §4.2: Lights → Move (walk + photo at the spot)
/// → Brain (maze, calculator). Needs setup, so it is opt-in.
const List<StageConfig> wakeUpRoutine = [
  StageConfig(ChallengeId.lightsOn),
  StageConfig(ChallengeId.walkSteps),
  StageConfig(ChallengeId.photoMatch),
  StageConfig(ChallengeId.tiltMaze),
  StageConfig(ChallengeId.brokenCalculator),
];

/// The one quick challenge of the "check I'm awake" ring after a Stop.
const List<StageConfig> awakeCheckStages = [
  StageConfig(ChallengeId.stroopTap, difficulty: 1),
];

String encodeStages(List<StageConfig> stages) =>
    jsonEncode([for (final s in stages) s.toJson()]);

/// Lenient decoding: unknown challenges are dropped, and anything unusable
/// (missing, invalid, or empty after dropping) yields [defaultStages]. An
/// explicitly empty list stays empty (a reminder-only alarm).
List<StageConfig> decodeStages(String? json) {
  if (json == null || json.isEmpty) return defaultStages;
  try {
    final raw = jsonDecode(json) as List<Object?>;
    if (raw.isEmpty) return const [];
    final stages = <StageConfig>[];
    for (final item in raw) {
      try {
        stages.add(StageConfig.fromJson(item! as Map<String, Object?>));
      } on Object {
        // Unknown challenge (e.g. from a newer build): skip it.
      }
    }
    return stages.isEmpty ? defaultStages : stages;
  } on Object {
    return defaultStages;
  }
}
