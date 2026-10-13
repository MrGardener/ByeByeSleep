import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/clock.dart';
import 'rule.dart';

/// Time sense: count the seconds in your head; no clock is shown.
class TimeSenseChallenge extends ConsumerStatefulWidget {
  const TimeSenseChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<TimeSenseChallenge> createState() => _TimeSenseState();
}

class _TimeSenseState extends ConsumerState<TimeSenseChallenge> {
  late final _rule = TimeSense.forDifficulty(widget.args.difficulty);
  Duration? _startedAt;
  String? _result;
  bool _done = false;

  void _start() => setState(() {
    _startedAt = ref.read(challengeClockProvider)();
    _result = null;
  });

  void _stop() {
    final elapsed = ref.read(challengeClockProvider)() - _startedAt!;
    setState(() {
      _startedAt = null;
      _result = _rule.accepts(elapsed) ? 'Spot on!' : _rule.feedback(elapsed);
    });
    if (_rule.accepts(elapsed) && !_done) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _rule.target.inSeconds;
    final within = (_rule.tolerance.inMilliseconds / 1000).toStringAsFixed(1);
    final counting = _startedAt != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.hourglass_bottom, size: 72),
        Text(
          'Count $seconds seconds in your head.',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        Text(
          'Tap Start, then Stop when you think $seconds seconds have passed '
          '(within $within s).',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_result != null)
          Text(_result!, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        counting
            ? FilledButton(
                key: const Key('time-stop'),
                onPressed: _stop,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Stop'),
                ),
              )
            : FilledButton.tonal(
                key: const Key('time-start'),
                onPressed: _start,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_result == null ? 'Start' : 'Try again'),
                ),
              ),
      ],
    );
  }
}
