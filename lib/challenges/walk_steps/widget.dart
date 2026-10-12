import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/env_sensors.dart';
import 'detector.dart';

class WalkChallenge extends ConsumerStatefulWidget {
  const WalkChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<WalkChallenge> createState() => _WalkChallengeState();
}

class _WalkChallengeState extends ConsumerState<WalkChallenge> {
  late final WalkDetector _d = WalkDetector(
    calibratedSteps: (widget.args.params['steps'] as num?)?.toInt(),
  );
  StreamSubscription<Duration>? _sub;
  bool? _permitted;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _askPermission();
  }

  Future<void> _askPermission() async {
    final sensors = ref.read(envSensorProvider);
    final ok = await sensors.requestActivityPermission();
    if (!mounted) return;
    setState(() => _permitted = ok);
    if (!ok || _sub != null) return;
    _sub = sensors.steps.listen((t) {
      final progress = _d.onStep(t);
      setState(() {});
      if (progress.passed && !_reported) {
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
    if (_permitted == false) {
      return FilledButton(
        key: const Key('walk-permission'),
        onPressed: _askPermission,
        child: const Text('Allow physical activity to count steps'),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.directions_walk, size: 72),
        Text(
          '${_d.counted} of ${_d.required} steps',
          key: const Key('walk-count'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(value: _d.counted / _d.required),
        ),
        const Text('Walk to your spot — the phone counts real steps only.'),
      ],
    );
  }
}
