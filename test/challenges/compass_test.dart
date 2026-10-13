import 'dart:math';

import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/compass/trial.dart';
import 'package:byebyesleep/challenges/compass/widget.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:byebyesleep/challenges/tilt_maze/physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_motion_source.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('trial', () {
    test('within 20° counts, 25° away does not', () {
      final t = CompassTrial([90]);
      t.update(108, ms(0));
      t.update(108, ms(2000));
      expect(t.passed, isTrue);
      final u = CompassTrial([90]);
      u.update(115, ms(0));
      u.update(115, ms(3000));
      expect(u.passed, isFalse);
    });

    test('a short wobble off target does not restart the hold', () {
      final t = CompassTrial([0]);
      for (var x = 0; x <= 1200; x += 20) {
        t.update(0, ms(x));
      }
      t.update(40, ms(1300)); // wobble for 0.3 s
      t.update(40, ms(1500));
      for (var x = 1520; x <= 2100; x += 20) {
        t.update(0, ms(x));
      }
      expect(t.passed, isTrue);
    });

    test('leaving for more than the grace time restarts the hold', () {
      final t = CompassTrial([0]);
      t.update(0, ms(0));
      t.update(0, ms(1500));
      t.update(90, ms(1600));
      t.update(90, ms(2400)); // 0.9 s away
      t.update(0, ms(2500));
      t.update(0, ms(4000));
      expect(t.passed, isFalse);
      t.update(0, ms(4600));
      expect(t.passed, isTrue);
    });

    test('targets are compass points at least 90° apart', () {
      final targets = CompassTrial.randomTargets(Random(4), count: 5);
      expect(targets, hasLength(5));
      for (final t in targets) {
        expect(t % 45, 0);
      }
      for (var i = 1; i < targets.length; i++) {
        final d = ((targets[i] - targets[i - 1]) % 360 + 540) % 360 - 180;
        expect(d.abs(), greaterThanOrEqualTo(90));
      }
    });

    test('the first rune always needs a turn from where you face', () {
      for (var seed = 0; seed < 50; seed++) {
        final t = CompassTrial.randomTargets(Random(seed), count: 2, from: 100);
        expect(turnTo(100, t.first).abs(), greaterThanOrEqualTo(90));
      }
    });

    test('compass point names', () {
      expect(compassPointName(0), 'north');
      expect(compassPointName(135), 'south-east');
      expect(compassPointName(270), 'west');
    });
  });

  group('heading filter', () {
    test('averages across north without swinging to south', () {
      final f = HeadingFilter();
      for (var i = 0; i < 50; i++) {
        f.add(i.isEven ? 355 : 5);
      }
      final h = f.heading!;
      expect(min(h, 360 - h), lessThan(3));
    });

    test('calms jitter', () {
      final f = HeadingFilter();
      final r = Random(1);
      var maxJump = 0.0;
      double? last;
      for (var i = 0; i < 200; i++) {
        f.add(90 + r.nextDouble() * 30 - 15);
        if (last != null) maxJump = max(maxJump, (f.heading! - last).abs());
        last = f.heading;
      }
      expect(maxJump, lessThan(4));
      expect((f.heading! - 90).abs(), lessThan(6));
    });
  });

  testWidgets('the challenge explains itself and passes facing the runes', (
    tester,
  ) async {
    final motion = FakeMotionSource(
      availableKinds: const {SensorKind.accelerometer, SensorKind.magnetometer},
    );
    var passed = 0;
    var clock = Duration.zero;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [motionSourceProvider.overrideWithValue(motion)],
        child: MaterialApp(
          home: Scaffold(
            body: CompassRunes(
              targets: const [0],
              clock: () => clock,
              args: ChallengeArgs(
                difficulty: 1,
                random: Random(1),
                onPassed: () => passed++,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('flat'), findsWidgets);
    expect(find.textContaining('north'), findsWidgets);
    // Flat phone pointing north.
    const gravity = Vec3(0, 0, 9.8);
    const north = Vec3(0, 20, -40);
    expect(headingDegrees(gravity, north).round() % 360, 0);
    for (var i = 0; i < 150; i++) {
      motion.accel.add(gravity);
      motion.mag.add(north);
      clock += ms(20);
      await tester.pump();
    }
    expect(passed, 1);
  });

  test('alarm challenge: more runes when harder, replaced without compass', () {
    expect(compassRunesFor(1), lessThan(compassRunesFor(5)));
    expect(
      resolveStage(const StageConfig(ChallengeId.compass), const {}).challenge,
      ChallengeId.brokenCalculator,
    );
  });
}
