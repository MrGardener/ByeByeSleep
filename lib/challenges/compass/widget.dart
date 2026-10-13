import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/motion.dart';
import '../core/types.dart';
import '../tilt_maze/physics.dart';
import 'trial.dart';

/// Runes for an alarm stage of [difficulty] 1–5.
int compassRunesFor(int difficulty) =>
    const [2, 3, 3, 4, 5][difficulty.clamp(1, 5) - 1];

/// Compass runes: hold the phone flat, turn your body to face each compass
/// point shown, and hold still for 2 s. Used by alarms and Compass Temple.
class CompassRunes extends ConsumerStatefulWidget {
  const CompassRunes({
    super.key,
    required this.args,
    this.runes,
    this.targets,
    this.clock,
  });

  final ChallengeArgs args;

  /// How many runes (default: by difficulty).
  final int? runes;

  /// Fixed targets (tests); otherwise random compass points.
  final List<double>? targets;
  final Duration Function()? clock;

  @override
  ConsumerState<CompassRunes> createState() => _CompassRunesState();
}

class _CompassRunesState extends ConsumerState<CompassRunes> {
  /// Made at the first reading, so the first rune is never the direction
  /// you already face (fixed [CompassRunes.targets] start at once).
  late CompassTrial? _t = widget.targets == null
      ? null
      : CompassTrial(widget.targets!);

  /// Placeholder until the first reading: shows the rune count.
  late final CompassTrial _waiting = CompassTrial(
    List.filled(widget.runes ?? compassRunesFor(widget.args.difficulty), 0),
  );

  CompassTrial get _trial => _t ?? _waiting;
  final _filter = HeadingFilter();
  final _subs = <StreamSubscription<Vec3>>[];
  final _watch = Stopwatch()..start();
  Timer? _silence;
  Vec3 _gravity = const Vec3(0, 0, 9.8);
  bool _reported = false;

  Duration _now() => widget.clock?.call() ?? _watch.elapsed;

  @override
  void initState() {
    super.initState();
    _silence = Timer(const Duration(seconds: 3), () {
      if (_filter.heading == null && mounted) widget.args.onUnavailable?.call();
    });
    final motion = ref.read(motionSourceProvider);
    _subs
      ..add(motion.accelerometer.listen((a) => _gravity = a))
      ..add(motion.magnetometer.listen(_onMagnetic));
  }

  void _onMagnetic(Vec3 m) {
    _filter.add(headingDegrees(_gravity, m));
    final heading = _filter.heading!;
    final trial = _t ??= CompassTrial(
      CompassTrial.randomTargets(
        widget.args.random,
        count: widget.runes ?? compassRunesFor(widget.args.difficulty),
        from: heading,
      ),
    );
    trial.update(heading, _now());
    if (!mounted) return;
    setState(() {});
    if (_trial.passed && !_reported) {
      _reported = true;
      widget.args.onPassed();
    }
  }

  @override
  void dispose() {
    _silence?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final heading = _filter.heading;
    final target = _t == null ? null : _trial.target;
    final turn = heading == null || target == null
        ? 0.0
        : turnTo(heading, target);
    final on = heading != null && _trial.isOn(heading);
    final hint = _trial.passed
        ? 'All runes lit!'
        : heading == null
        ? 'Hold the phone flat…'
        : on
        ? 'Hold still…'
        : 'Turn ${turn > 0 ? 'right' : 'left'} (${turn.abs().round()}°)';
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            _t == null
                ? 'Hold the phone flat'
                : target == null
                ? 'Done'
                : 'Rune ${_trial.index + 1} of ${_trial.targets.length}: '
                      'face ${compassPointName(target)}',
            key: const Key('compass-target'),
            style: text.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: _trial.holdProgress,
                    strokeWidth: 8,
                    color: scheme.tertiary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
                // Points to where you must turn; straight up = facing it.
                Transform.rotate(
                  angle: turn * pi / 180,
                  child: Icon(
                    Icons.navigation,
                    size: 96,
                    color: on ? scheme.tertiary : scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(hint, key: const Key('compass-hint'), style: text.titleMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _trial.targets.length; i++)
                Icon(
                  i < _trial.index ? Icons.auto_awesome : Icons.circle_outlined,
                  color: i < _trial.index ? scheme.tertiary : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'How to win:\n'
            '1. Hold the phone flat, screen up, like a tray.\n'
            '2. Turn your whole body until the arrow points to the top of '
            'the phone.\n'
            '3. Keep still until the ring fills (2 s) — the rune lights up.\n'
            'Arrow spinning? Wave the phone in a figure 8 to calibrate.',
          ),
        ],
      ),
    );
  }
}
