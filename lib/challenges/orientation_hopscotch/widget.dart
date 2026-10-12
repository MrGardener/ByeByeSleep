import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/motion.dart';
import 'detector.dart';

const _labels = {
  PhoneOrientation.faceUp: ('Face up', Icons.arrow_upward),
  PhoneOrientation.faceDown: ('Face down', Icons.arrow_downward),
  PhoneOrientation.portrait: ('Upright', Icons.stay_current_portrait),
  PhoneOrientation.portraitUpsideDown: ('Upside down', Icons.screen_rotation),
  PhoneOrientation.landscapeLeft: (
    'On its left side',
    Icons.stay_current_landscape,
  ),
  PhoneOrientation.landscapeRight: (
    'On its right side',
    Icons.stay_current_landscape,
  ),
};

class HopscotchChallenge extends ConsumerStatefulWidget {
  const HopscotchChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<HopscotchChallenge> createState() => _HopscotchChallengeState();
}

class _HopscotchChallengeState extends ConsumerState<HopscotchChallenge> {
  late final HopscotchDetector _d = HopscotchDetector(
    difficulty: widget.args.difficulty,
    random: widget.args.random,
  );
  final _clock = Stopwatch()..start();
  StreamSubscription<Object?>? _sub;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(motionSourceProvider).accelerometer.listen((a) {
      final before = _d.step;
      _d.onAccel(a, _clock.elapsed);
      if (_d.step != before) setState(() {});
      if (_d.progress.passed && !_reported) {
        _reported = true;
        widget.args.onPassed();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _d.target;
    final (label, icon) = target == null
        ? ('Done', Icons.check_circle)
        : _labels[target]!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 96, key: const Key('hopscotch-icon')),
        Text(
          label,
          key: const Key('hopscotch-target'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _d.sequence.length; i++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  i < _d.step ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                ),
              ),
          ],
        ),
        Text('Each move within ${_d.stepLimit.inMilliseconds / 1000} s'),
      ],
    );
  }
}
