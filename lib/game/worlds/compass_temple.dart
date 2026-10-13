import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/motion.dart';
import '../../challenges/core/types.dart';
import '../../challenges/tilt_maze/physics.dart';
import 'world_kit.dart';

/// Face each target heading (±15°) for 2 s, in order.
class CompassTrial {
  CompassTrial(this.targets);

  static const hold = Duration(seconds: 2);

  /// Four headings, each at least 60° from the one before.
  static List<double> randomTargets(Random random) {
    final out = <double>[random.nextDouble() * 360];
    while (out.length < 4) {
      final turn = 60 + random.nextDouble() * 240; // 60–300° away
      out.add((out.last + turn) % 360);
    }
    return out;
  }

  final List<double> targets;
  int index = 0;
  Duration? _since;
  Duration _held = Duration.zero;

  bool get passed => index >= targets.length;

  double get progress => passed
      ? 1
      : (index + _held.inMicroseconds / hold.inMicroseconds) / targets.length;

  void update(double heading, Duration now) {
    if (passed) return;
    if (!headingOk(heading, targets[index])) {
      _since = null;
      _held = Duration.zero;
      return;
    }
    final since = _since ??= now;
    _held = now - since;
    if (_held >= hold) {
      index++;
      _since = null;
      _held = Duration.zero;
    }
  }
}

/// Compass Temple: turn to face each rune's direction, phone held flat.
class CompassTempleWorld extends ConsumerStatefulWidget {
  const CompassTempleWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  ConsumerState<CompassTempleWorld> createState() => _CompassTempleState();
}

class _CompassTempleState extends ConsumerState<CompassTempleWorld> {
  final _trial = CompassTrial(CompassTrial.randomTargets(Random()));
  final _subs = <StreamSubscription<Vec3>>[];
  late final Watchdog _watchdog;
  Vec3 _gravity = const Vec3(0, 0, 9.8);
  double? _heading;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _watchdog = Watchdog(() => widget.args.onUnavailable?.call());
    final motion = ref.read(motionSourceProvider);
    final now = ref.read(gameClockProvider);
    _subs
      ..add(motion.accelerometer.listen((a) => _gravity = a))
      ..add(
        motion.magnetometer.listen((m) {
          _watchdog.heard();
          final heading = headingDegrees(_gravity, m);
          _trial.update(heading, now());
          setState(() => _heading = heading);
          if (_trial.passed && !_reported) {
            _reported = true;
            widget.args.onPassed();
          }
        }),
      );
  }

  @override
  void dispose() {
    _watchdog.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final done = _trial.passed;
    final target = done ? 0.0 : _trial.targets[_trial.index];
    final turn = heading == null
        ? 0.0
        : ((target - heading) % 360 + 540) % 360 - 180;
    return WorldPanel(
      icon: Transform.rotate(
        angle: turn * pi / 180,
        child: Icon(
          Icons.navigation,
          size: 96,
          color: turn.abs() <= 15
              ? Theme.of(context).colorScheme.tertiary
              : null,
        ),
      ),
      message: done
          ? 'All runes lit!'
          : 'Rune ${_trial.index + 1} of ${_trial.targets.length}',
      detail: heading == null
          ? 'Hold the phone flat.'
          : turn.abs() <= 15
          ? 'Hold still…'
          : 'Turn ${turn > 0 ? 'right' : 'left'} toward the arrow.',
      progress: _trial.progress,
    );
  }
}
