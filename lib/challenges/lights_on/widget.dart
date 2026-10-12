import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/env_sensors.dart';
import '../core/types.dart';
import 'detector.dart';

/// Black screen until the room light is on (spec §4.2 stage 1).
class LightsChallenge extends ConsumerStatefulWidget {
  const LightsChallenge({super.key, required this.args, this.elapsed});

  final ChallengeArgs args;

  /// Monotonic time source; tests inject one.
  final Duration Function()? elapsed;

  @override
  ConsumerState<LightsChallenge> createState() => _LightsChallengeState();
}

class _LightsChallengeState extends ConsumerState<LightsChallenge> {
  late final LightsDetector _d = LightsDetector(
    calibratedLux: (widget.args.params['lux'] as num?)?.toDouble(),
  );
  final _stopwatch = Stopwatch()..start();
  StreamSubscription<double>? _sub;
  Timer? _ticker;
  ChallengeProgress _progress = ChallengeProgress.none;
  double _lux = 0;
  bool _reported = false;

  Duration _elapsed() => (widget.elapsed ?? () => _stopwatch.elapsed)();

  void _evaluate() {
    setState(() => _progress = _d.onLux(_lux, _elapsed()));
    if (_progress.passed && !_reported) {
      _reported = true;
      _ticker?.cancel();
      widget.args.onPassed();
    }
  }

  @override
  void initState() {
    super.initState();
    _sub = ref.read(envSensorProvider).lux.listen((lux) {
      _lux = lux;
      _evaluate();
    });
    // The light sensor only reports changes; in a steadily lit room no more
    // events come, so keep re-checking the last reading.
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_lux > 0) _evaluate();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              color: Colors.white24,
              size: 64,
            ),
            const Text(
              'Turn on the light',
              style: TextStyle(color: Colors.white38, fontSize: 20),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(value: _progress.value),
            ),
            Text(
              '${_lux.round()} / ${_d.threshold.round()} lux',
              key: const Key('lights-level'),
              style: const TextStyle(color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }
}
