import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/motion.dart';
import '../core/types.dart';
import 'maze.dart';
import 'physics.dart';

/// Level → maze size.
const _sizes = [5, 7, 9, 11, 11];

class TiltMazeChallenge extends ConsumerStatefulWidget {
  const TiltMazeChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<TiltMazeChallenge> createState() => _TiltMazeChallengeState();
}

class _TiltMazeChallengeState extends ConsumerState<TiltMazeChallenge>
    with SingleTickerProviderStateMixin {
  late final int _level = widget.args.difficulty.clamp(1, 5);
  late final Maze _maze = Maze.generate(_sizes[_level - 1], widget.args.random);
  final Ball _ball = Ball.atStart();
  late final Ticker _ticker = createTicker(_tick);
  final _subs = <StreamSubscription<Object?>>[];
  Vec3 _gravity = const Vec3(0, 0, 9.8);
  double _rotationRate = 0; // rad/s around the screen axis
  double _angle = 0; // maze rotation (level 4+)
  Offset? _finger; // level 1, in cell units
  Vec3? _magnetic; // level 5
  double? _startHeading;
  bool _onHeading = true;
  double _arrow = 0; // degrees from where the phone points to the target
  Duration _elapsed = Duration.zero;
  Duration _last = Duration.zero;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final motion = ref.read(motionSourceProvider);
    if (_level >= 2) {
      _subs.add(motion.accelerometer.listen((a) => _gravity = a));
    }
    if (_level == 4) {
      _subs.add(motion.gyroscope.listen((g) => _rotationRate = g.z));
    }
    if (_level == 5) {
      _subs.add(motion.magnetometer.listen(_onMagnetic));
    }
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Level 5: the ball only moves while the phone points at the target.
  void _onMagnetic(Vec3 m) {
    _magnetic = m;
    final heading = headingDegrees(_gravity, m);
    final start = _startHeading ??= heading;
    final target = targetHeading(start, _elapsed);
    _arrow = ((target - heading) % 360 + 540) % 360 - 180;
    final ok = headingOk(heading, target);
    if (ok != _onHeading) setState(() => _onHeading = ok);
  }

  Offset _accel() {
    if (_level == 1) {
      final f = _finger;
      return f == null ? Offset.zero : (f - _ball.pos) * 12 - _ball.vel * 3;
    }
    final screen = tiltToAccel(_gravity, inverted: _level == 3);
    return _level == 4 ? rotate(screen, -_angle) : screen;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _elapsed = elapsed;
    if (_level == 4) _angle += _rotationRate * dt;
    if (_level == 5 && _magnetic != null) _onMagnetic(_magnetic!);
    if (_level == 5 && !_onHeading) {
      _ball.vel = Offset.zero; // frozen until the phone faces the target
    } else {
      stepBall(_maze, _ball, _accel(), dt);
    }
    setState(() {});
    if (isAtGoal(_maze, _ball) && !_reported) {
      _reported = true;
      _ticker.stop();
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = switch (_level) {
      1 => 'Drag your finger to pull the ball.',
      3 => 'Controls are reversed!',
      4 => 'Turning the phone turns the maze.',
      5 => 'Keep facing the moving arrow, or the ball freezes.',
      _ => 'Tilt the phone to roll the ball.',
    };
    return LayoutBuilder(
      builder: (context, box) {
        final hintHeight = _level == 5 ? 56.0 : 32.0;
        final side = min(
          box.maxWidth,
          box.maxHeight.isFinite ? box.maxHeight - hintHeight : box.maxWidth,
        );
        final cell = side / _maze.size;
        Offset toCells(Offset p) => p / cell;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: hintHeight,
              child: Column(
                children: [
                  Text(hint),
                  if (_level == 5)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: _arrow * pi / 180,
                          child: const Icon(Icons.navigation, size: 20),
                        ),
                        Text(
                          _onHeading ? 'On course' : 'Turn to the arrow!',
                          key: Key(_onHeading ? 'heading-ok' : 'heading-off'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            GestureDetector(
              onPanStart: (d) => _finger = toCells(d.localPosition),
              onPanUpdate: (d) => _finger = toCells(d.localPosition),
              onPanEnd: (_) => _finger = null,
              child: Transform.rotate(
                angle: _angle,
                child: CustomPaint(
                  key: const Key('maze'),
                  size: Size.square(side),
                  painter: _MazePainter(_maze, _ball, scheme),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter(this.maze, this.ball, this.scheme);

  final Maze maze;
  final Ball ball;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / maze.size;
    final wall = Paint()
      ..color = scheme.onSurface
      ..strokeWidth = max(2, cell * 0.08)
      ..strokeCap = StrokeCap.round;
    final g = maze.size - 1;
    canvas.drawRect(
      Rect.fromLTWH(g * cell, g * cell, cell, cell).deflate(cell * 0.1),
      Paint()..color = scheme.tertiary,
    );
    for (var c = 0; c < maze.size * maze.size; c++) {
      final x = (c % maze.size) * cell, y = (c ~/ maze.size) * cell;
      if (maze.wall(c, Direction.north)) {
        canvas.drawLine(Offset(x, y), Offset(x + cell, y), wall);
      }
      if (maze.wall(c, Direction.west)) {
        canvas.drawLine(Offset(x, y), Offset(x, y + cell), wall);
      }
      if (maze.wall(c, Direction.east)) {
        canvas.drawLine(Offset(x + cell, y), Offset(x + cell, y + cell), wall);
      }
      if (maze.wall(c, Direction.south)) {
        canvas.drawLine(Offset(x, y + cell), Offset(x + cell, y + cell), wall);
      }
    }
    canvas.drawCircle(
      ball.pos * cell,
      ballRadius * cell,
      Paint()..color = scheme.primary,
    );
  }

  @override
  bool shouldRepaint(_MazePainter old) => true;
}
