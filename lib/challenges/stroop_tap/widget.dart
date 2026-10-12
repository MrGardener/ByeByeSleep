import 'package:flutter/material.dart';

import '../core/challenge.dart';
import 'detector.dart';

Color inkColorValue(InkColor c) => switch (c) {
  InkColor.red => const Color(0xFFE53935),
  InkColor.green => const Color(0xFF43A047),
  InkColor.blue => const Color(0xFF1E88E5),
  InkColor.yellow => const Color(0xFFFDD835),
  InkColor.purple => const Color(0xFF8E24AA),
};

class StroopChallenge extends StatefulWidget {
  const StroopChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<StroopChallenge> createState() => _StroopChallengeState();
}

class _StroopChallengeState extends State<StroopChallenge> {
  late final StroopDetector _d = StroopDetector(
    difficulty: widget.args.difficulty,
    random: widget.args.random,
  );
  bool _reported = false;

  void _choose(InkColor c) {
    setState(() => _d.choose(c));
    if (_d.progress.passed && !_reported) {
      _reported = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _d.word,
          key: const Key('stroop-word'),
          style: text.displayMedium!.copyWith(
            color: inkColorValue(_d.ink),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _d.progress.value),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final c in _d.choices)
              OutlinedButton(
                key: Key('stroop-${c.name}'),
                onPressed: () => _choose(c),
                child: Text(c.name.toUpperCase()),
              ),
          ],
        ),
      ],
    );
  }
}
