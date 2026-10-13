import 'dart:math';

import 'package:flutter/material.dart';

import '../../challenges/core/challenge.dart';
import '../../challenges/tilt_maze/widget.dart';
import 'world_kit.dart';

/// Three tilt mazes in a row: tilt, reversed tilt, then a turning maze.
class LabyrinthWorld extends StatefulWidget {
  const LabyrinthWorld({super.key, required this.args});

  static const levels = [2, 3, 4];

  final WorldArgs args;

  @override
  State<LabyrinthWorld> createState() => _LabyrinthWorldState();
}

class _LabyrinthWorldState extends State<LabyrinthWorld> {
  final _random = Random();
  int _maze = 0;

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
