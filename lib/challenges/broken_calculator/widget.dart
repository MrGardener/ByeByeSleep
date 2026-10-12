import 'package:flutter/material.dart';

import '../core/challenge.dart';
import 'detector.dart';

class BrokenCalculatorChallenge extends StatefulWidget {
  const BrokenCalculatorChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<BrokenCalculatorChallenge> createState() =>
      _BrokenCalculatorChallengeState();
}

class _BrokenCalculatorChallengeState extends State<BrokenCalculatorChallenge> {
  late final BrokenCalculatorDetector _d = BrokenCalculatorDetector(
    difficulty: widget.args.difficulty,
    random: widget.args.random,
  );
  bool _reported = false;

  void _after(void Function() action) {
    setState(action);
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
          _d.problem,
          key: const Key('calc-problem'),
          style: text.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          _d.entry.isEmpty ? '_' : _d.entry,
          key: const Key('calc-entry'),
          style: text.headlineMedium,
        ),
        Text(
          'Solved ${(_d.progress.value * _d.required).round()} of ${_d.required}',
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 9; i++) _key(i),
              OutlinedButton(
                key: const Key('calc-back'),
                onPressed: () => _after(_d.backspace),
                child: const Icon(Icons.backspace_outlined),
              ),
              _key(9),
              FilledButton.tonal(
                key: const Key('calc-submit'),
                onPressed: () => _after(_d.submit),
                child: const Icon(Icons.check),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(int buttonIndex) => FilledButton(
    key: ValueKey('calc-key-$buttonIndex'),
    onPressed: () => _after(() => _d.press(buttonIndex)),
    child: Text('${_d.keypad[buttonIndex]}'),
  );
}
