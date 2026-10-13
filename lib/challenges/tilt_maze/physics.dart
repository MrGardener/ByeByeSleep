import 'dart:math';
import 'dart:ui';

import '../core/types.dart';
import 'maze.dart';

/// Ball radius in cell units.
const ballRadius = 0.3;
// A "heavy" ball: little drag, strong pull from the tilt (owner: it dragged).
const _maxSpeed = 10.0; // cells per second
const _maxStep = 1 / 60; // seconds; longer frames are split (≤ 1/6 cell)
const _frictionPerFrame = 0.97; // at 60 fps
const _tiltGain = 4.5;

class Ball {
  Ball(this.pos, [this.vel = Offset.zero]);

  Ball.atStart() : this(const Offset(0.5, 0.5));

  /// Position in cell units: (x, y), the start cell spans 0..1.
  Offset pos;
  Offset vel;
}

/// Screen-space acceleration from accelerometer gravity: tilting the right
/// edge down rolls the ball right; tilting the top edge down rolls it up.
Offset tiltToAccel(Vec3 a, {bool inverted = false}) {
  final v = Offset(-a.x, a.y) * _tiltGain;
  return inverted ? -v : v;
}

Offset rotate(Offset v, double angle) => Offset(
  v.dx * cos(angle) - v.dy * sin(angle),
  v.dx * sin(angle) + v.dy * cos(angle),
);

bool isAtGoal(Maze m, Ball b) =>
    b.pos.dx.floor() == m.size - 1 && b.pos.dy.floor() == m.size - 1;

/// Advances [b] by [dt] seconds under [accel] (cells/s²), stopping at walls.
void stepBall(Maze m, Ball b, Offset accel, double dt) {
  while (dt > 0) {
    final step = min(dt, _maxStep);
    _step(m, b, accel, step);
    dt -= step;
  }
}

void _step(Maze m, Ball b, Offset accel, double dt) {
  var v = (b.vel + accel * dt) * pow(_frictionPerFrame, dt * 60).toDouble();
  if (v.distance > _maxSpeed) v = v / v.distance * _maxSpeed;

  // Move along x within the current row, then along y within the new column,
  // so the ball can only change cell through an open passage.
  var x = b.pos.dx + v.dx * dt;
  var y = b.pos.dy;
  final cx = b.pos.dx.floor(), cy = y.floor();
  final cell = cy * m.size + cx;
  if (x + ballRadius > cx + 1 && _blockedX(m, cell, Direction.east, y, cy)) {
    x = cx + 1 - ballRadius;
    v = Offset(0, v.dy);
  } else if (x - ballRadius < cx && _blockedX(m, cell, Direction.west, y, cy)) {
    x = cx + ballRadius;
    v = Offset(0, v.dy);
  }

  y = y + v.dy * dt;
  final nx = x.floor();
  final cell2 = cy * m.size + nx;
  if (y + ballRadius > cy + 1 && _blockedY(m, cell2, Direction.south, x, nx)) {
    y = cy + 1 - ballRadius;
    v = Offset(v.dx, 0);
  } else if (y - ballRadius < cy &&
      _blockedY(m, cell2, Direction.north, x, nx)) {
    y = cy + ballRadius;
    v = Offset(v.dx, 0);
  }

  b
    ..pos = Offset(x, y)
    ..vel = v;
}

/// Whether moving sideways out of [cell] towards [d] hits a wall — the wall
/// itself, or the end of a horizontal wall in the next cell the ball overlaps.
bool _blockedX(Maze m, int cell, Direction d, double y, int cy) {
  if (m.wall(cell, d)) return true;
  final next = m.neighbour(cell, d);
  return (y - ballRadius < cy && m.wall(next, Direction.north)) ||
      (y + ballRadius > cy + 1 && m.wall(next, Direction.south));
}

bool _blockedY(Maze m, int cell, Direction d, double x, int cx) {
  if (m.wall(cell, d)) return true;
  final next = m.neighbour(cell, d);
  return (x - ballRadius < cx && m.wall(next, Direction.west)) ||
      (x + ballRadius > cx + 1 && m.wall(next, Direction.east));
}

/// Compass heading in degrees (0 = magnetic north, 90 = east) of the phone's
/// top edge, compensated for tilt (Android's getRotationMatrix azimuth).
double headingDegrees(Vec3 gravity, Vec3 magnetic) {
  // East = magnetic × gravity, north = gravity × east.
  final ex = magnetic.y * gravity.z - magnetic.z * gravity.y;
  final ey = magnetic.z * gravity.x - magnetic.x * gravity.z;
  final ez = magnetic.x * gravity.y - magnetic.y * gravity.x;
  final ny = gravity.z * ex - gravity.x * ez;
  final azimuth = atan2(ey, ny) * 180 / pi;
  return (azimuth + 360) % 360;
}

/// Within ±15° of [target], wrap-around safe.
bool headingOk(double heading, double target) {
  final diff = ((heading - target) % 360 + 540) % 360 - 180;
  return diff.abs() <= 15;
}
