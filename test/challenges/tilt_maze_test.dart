import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/tilt_maze/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:byebyesleep/challenges/tilt_maze/maze.dart';
import 'package:byebyesleep/challenges/tilt_maze/physics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_motion_source.dart';

(int, int) cellOf(Offset p) => (p.dx.floor(), p.dy.floor());

bool open(Maze m, (int, int) from, (int, int) to) {
  final (fx, fy) = from;
  final (tx, ty) = to;
  final dir = tx > fx
      ? Direction.east
      : tx < fx
      ? Direction.west
      : ty > fy
      ? Direction.south
      : Direction.north;
  return !m.wall(fy * m.size + fx, dir);
}

void main() {
  test('maze_isPerfect', () {
    for (final size in [5, 7, 9, 11]) {
      final m = Maze.generate(size, Random(size));
      // Spanning tree: every cell reachable and exactly size²-1 passages.
      final seen = <int>{0};
      final queue = [0];
      var passages = 0;
      while (queue.isNotEmpty) {
        final c = queue.removeLast();
        for (final d in Direction.values) {
          if (m.wall(c, d)) continue;
          final n = m.neighbour(c, d);
          if (seen.add(n)) queue.add(n);
        }
      }
      for (var c = 0; c < size * size; c++) {
        for (final d in [Direction.east, Direction.south]) {
          if (!m.wall(c, d)) passages++;
        }
      }
      expect(seen, hasLength(size * size));
      expect(passages, size * size - 1);
      expect(m.solve().first, 0);
      expect(m.solve().last, size * size - 1);
    }
  });

  test('outer border is always walled', () {
    final m = Maze.generate(5, Random(1));
    for (var i = 0; i < 5; i++) {
      expect(m.wall(i, Direction.north), isTrue);
      expect(m.wall(20 + i, Direction.south), isTrue);
      expect(m.wall(i * 5, Direction.west), isTrue);
      expect(m.wall(i * 5 + 4, Direction.east), isTrue);
    }
  });

  test('ball_neverCrossesWalls', () {
    final r = Random(2);
    final m = Maze.generate(7, r);
    final ball = Ball.atStart();
    for (var i = 0; i < 10000; i++) {
      final before = cellOf(ball.pos);
      final accel = Offset(r.nextDouble() * 20 - 10, r.nextDouble() * 20 - 10);
      stepBall(m, ball, accel, 1 / 60);
      final after = cellOf(ball.pos);
      final (bx, by) = before;
      final (ax, ay) = after;
      expect((ax - bx).abs() <= 1 && (ay - by).abs() <= 1, isTrue);
      if (ax != bx && ay != by) {
        final viaX = open(m, before, (ax, by)) && open(m, (ax, by), after);
        final viaY = open(m, before, (bx, ay)) && open(m, (bx, ay), after);
        expect(
          viaX || viaY,
          isTrue,
          reason: 'diagonal through walls at step $i',
        );
      } else if (before != after) {
        expect(
          open(m, before, after),
          isTrue,
          reason: 'crossed wall at step $i',
        );
      }
    }
  });

  test('ball_reachesGoalFollowingSolution', () {
    final m = Maze.generate(9, Random(3));
    final ball = Ball.atStart();
    final path = m.solve();
    var target = 1;
    for (var i = 0; i < 20000 && !isAtGoal(m, ball); i++) {
      final c = path[target];
      final centre = Offset(c % m.size + 0.5, c ~/ m.size + 0.5);
      if ((centre - ball.pos).distance < 0.2 && target < path.length - 1) {
        target++;
      }
      stepBall(m, ball, (centre - ball.pos) * 20 - ball.vel * 4, 1 / 60);
    }
    expect(isAtGoal(m, ball), isTrue);
  });

  test('tilt maps phone tilt to screen directions', () {
    // Right edge down: gravity on -x → ball rolls right.
    expect(tiltToAccel(const Vec3(-3, 0, 9)).dx, greaterThan(0));
    // Top edge down: gravity on -y → ball rolls up the screen.
    expect(tiltToAccel(const Vec3(0, -3, 9)).dy, lessThan(0));
  });

  test('invertedControlsFlipAxes', () {
    const a = Vec3(-3, 2, 9);
    expect(tiltToAccel(a, inverted: true), -tiltToAccel(a));
  });

  test('rotationTransformsAccel', () {
    final v = rotate(const Offset(1, 0), pi / 2);
    expect(v.dx, closeTo(0, 1e-9));
    expect(v.dy, closeTo(1, 1e-9));
  });

  for (var level = 1; level <= 5; level++) {
    testWidgets('maze widget renders at level $level', (tester) async {
      final motion = FakeMotionSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [motionSourceProvider.overrideWithValue(motion)],
          child: MaterialApp(
            home: Scaffold(
              body: TiltMazeChallenge(
                args: ChallengeArgs(
                  difficulty: level,
                  random: Random(level),
                  onPassed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      motion.accel.add(const Vec3(-3, 0, 9));
      motion.gyro.add(const Vec3(0, 0, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('maze')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('heading_flatNorthEastSouth', () {
    const flat = Vec3(0, 0, 9.8);
    expect(headingDegrees(flat, const Vec3(0, 30, -40)), closeTo(0, 0.5));
    expect(headingDegrees(flat, const Vec3(30, 0, -40)), closeTo(270, 0.5));
    expect(headingDegrees(flat, const Vec3(-30, 0, -40)), closeTo(90, 0.5));
    expect(headingDegrees(flat, const Vec3(0, -30, -40)), closeTo(180, 0.5));
  });

  test('headingOk_wrapsAround', () {
    expect(headingOk(359, 5), isTrue);
    expect(headingOk(5, 359), isTrue);
    expect(headingOk(100, 120), isFalse);
    expect(headingOk(100, 114), isTrue);
  });

  test('targetHeading_speedBelow10DegPerSecond', () {
    var maxRate = 0.0;
    for (var ms = 0; ms < 60000; ms += 100) {
      final a = targetHeading(200, Duration(milliseconds: ms));
      final b = targetHeading(200, Duration(milliseconds: ms + 100));
      maxRate = max(maxRate, (b - a).abs() * 10);
    }
    expect(maxRate, lessThanOrEqualTo(10));
    expect(targetHeading(200, Duration.zero), closeTo(200, 1e-9));
  });

  testWidgets('maze5_frozenWhenOffHeading', (tester) async {
    final motion = FakeMotionSource();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [motionSourceProvider.overrideWithValue(motion)],
        child: MaterialApp(
          home: Scaffold(
            body: TiltMazeChallenge(
              args: ChallengeArgs(
                difficulty: 5,
                random: Random(5),
                onPassed: () {},
              ),
            ),
          ),
        ),
      ),
    );
    motion.accel.add(const Vec3(0, 0, 9.8));
    motion.mag.add(const Vec3(0, 30, -40)); // start heading 0°
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('heading-ok')), findsOneWidget);
    motion.mag.add(const Vec3(30, 0, -40)); // turned to 270°
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('heading-off')), findsOneWidget);
  });
}
