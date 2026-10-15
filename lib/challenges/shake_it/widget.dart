import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/clock.dart';
import '../core/motion.dart';
import 'counter.dart';

/// Shake it: shake the phone hard until the counter is full.
class ShakeItChallenge extends ConsumerStatefulWidget {
  const ShakeItChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<ShakeItChallenge> createState() => _ShakeItState();
}

class _ShakeItState extends ConsumerState<ShakeItChallenge> {
  late final ShakeCounter _counter = switch (widget.args.params['count']) {
    final int n => ShakeCounter(n), // tests
    _ => ShakeCounter.forDifficulty(widget.args.difficulty),
  };
  StreamSubscription<Object?>? _sub;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final clock = ref.read(challengeClockProvider);
    _sub = ref
        .read(motionSourceProvider)
        .accelerometer
        .listen(
          (a) {
            if (!_counter.onAccel(a, clock())) return;
            setState(() {});
            if (_counter.passed && !_reported) {
              _reported = true;
              widget.args.onPassed();
            }
          },
          onError: (Object _) {
            if (mounted && !_reported) widget.args.onUnavailable?.call();
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.edgesensor_high, size: 96, color: scheme.primary),
        const SizedBox(height: 12),
        Text(
          'Hold the phone tightly and shake it hard.',
          style: text.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        SizedBox.square(
          dimension: 160,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: _counter.progress,
                strokeWidth: 12,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
              Center(
                child: Text(
                  '${_counter.count} / ${_counter.target}',
                  key: const Key('shake-count'),
                  style: text.headlineMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
