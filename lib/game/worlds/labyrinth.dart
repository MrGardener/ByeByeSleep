import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/challenge.dart';
import '../../challenges/core/motion.dart';
import '../../challenges/core/types.dart';
import '../../challenges/tilt_maze/widget.dart';
import 'world_kit.dart';

/// Three tilt mazes in a row: tilt, reversed tilt, then a turning maze.
class LabyrinthWorld extends ConsumerStatefulWidget {
  const LabyrinthWorld({super.key, required this.args});

  static const levels = [2, 3, 4];

  final WorldArgs args;

  @override
  ConsumerState<LabyrinthWorld> createState() => _LabyrinthWorldState();
}

class _LabyrinthWorldState extends ConsumerState<LabyrinthWorld> {
  final _random = Random();
  int _maze = 0;
  late final Watchdog _watchdog;
  StreamSubscription<Vec3>? _tilt;

  // A silent accelerometer would leave the ball still for ever.
  @override
  void initState() {
    super.initState();
    _watchdog = Watchdog(() => widget.args.onUnavailable?.call());
    _tilt = ref.read(motionSourceProvider).accelerometer.listen((_) {
      _watchdog.heard();
      _tilt?.cancel();
    });
  }

  @override
  void dispose() {
    _watchdog.cancel();
    _tilt?.cancel();
    super.dispose();
  }

  void _next() {
    if (_maze == LabyrinthWorld.levels.length - 1) {
      widget.args.onPassed();
    } else {
      setState(() => _maze++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Maze ${_maze + 1} of ${LabyrinthWorld.levels.length}'),
        Expanded(
          child: TiltMazeChallenge(
            key: ValueKey(_maze),
            args: ChallengeArgs(
              difficulty: LabyrinthWorld.levels[_maze],
              random: _random,
              onPassed: _next,
            ),
          ),
        ),
      ],
    );
  }
}
