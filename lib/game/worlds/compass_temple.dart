import 'dart:math';

import 'package:flutter/material.dart';

import '../../challenges/compass/widget.dart';
import '../../challenges/core/challenge.dart';
import 'world_kit.dart';

export '../../challenges/compass/trial.dart';

/// Compass Temple: four compass runes (the same challenge alarms can use).
class CompassTempleWorld extends StatelessWidget {
  const CompassTempleWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  Widget build(BuildContext context) => CompassRunes(
    runes: 4,
    args: ChallengeArgs(
      difficulty: 4,
      random: Random(),
      onPassed: args.onPassed,
      onUnavailable: args.onUnavailable,
    ),
  );
}
