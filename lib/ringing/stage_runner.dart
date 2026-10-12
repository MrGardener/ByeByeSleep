import 'dart:math';

import 'package:flutter/material.dart';

import '../challenges/core/challenge.dart';
import '../challenges/registry.dart';
import 'stage_engine.dart';

/// Shows the running stage: its challenge, a hint after 2 min and a
/// "different challenge" button after 5 min.
class StageRunner extends StatelessWidget {
  const StageRunner({
    super.key,
    required this.phase,
    required this.random,
    required this.onPassed,
    required this.onFallback,
  });

  final Running phase;
  final Random random;
  final VoidCallback onPassed;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    final definition = definitionFor(phase.stage.challenge);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(definition.title, style: text.titleLarge),
        Text(definition.instructions, textAlign: TextAlign.center),
        if (phase.hintVisible)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Hint: ${definition.instructions}',
              key: const Key('hint'),
              style: text.bodySmall,
            ),
          ),
        if (phase.fallbackAvailable)
          TextButton(
            key: const Key('fallback'),
            onPressed: onFallback,
            child: const Text('Try a different challenge'),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: definition.build(
              ChallengeArgs(
                difficulty: phase.stage.difficulty,
                random: random,
                onPassed: onPassed,
                params: phase.stage.params,
                onUnavailable: onFallback,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
