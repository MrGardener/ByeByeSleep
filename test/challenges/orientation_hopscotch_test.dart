import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/orientation_hopscotch/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:byebyesleep/challenges/orientation_hopscotch/detector.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_motion_source.dart';

const g = 9.8;

Vec3 gravityFor(PhoneOrientation o) => switch (o) {
  PhoneOrientation.faceUp => const Vec3(0, 0, g),
  PhoneOrientation.faceDown => const Vec3(0, 0, -g),
  PhoneOrientation.portrait => const Vec3(0, g, 0),
  PhoneOrientation.portraitUpsideDown => const Vec3(0, -g, 0),
  PhoneOrientation.landscapeLeft => const Vec3(g, 0, 0),
  PhoneOrientation.landscapeRight => const Vec3(-g, 0, 0),
};

void main() {
  test('classify_axes', () {
    for (final o in PhoneOrientation.values) {
      expect(classifyOrientation(gravityFor(o)), o);
    }
    expect(classifyOrientation(const Vec3(5, 5, 5)), isNull); // tilted
    expect(
      classifyOrientation(const Vec3(1, 7.5, 6)),
      PhoneOrientation.portrait,
    );
  });

  /// Feeds [o] every 50 ms for [hold]; returns the time after.
  Duration hold(
    HopscotchDetector d,
    PhoneOrientation o,
    Duration t,
    Duration hold,
  ) {
    final end = t + hold;
    while (t <= end) {
      d.onAccel(gravityFor(o), t);
      t += const Duration(milliseconds: 50);
    }
    return t;
  }

  test('sequence length and no repeats', () {
    for (var difficulty = 1; difficulty <= 5; difficulty++) {
      final d = HopscotchDetector(
        difficulty: difficulty,
        random: Random(difficulty),
      );
      expect(d.sequence, hasLength(difficulty + 2));
      for (var i = 1; i < d.sequence.length; i++) {
        expect(d.sequence[i], isNot(d.sequence[i - 1]));
      }
    }
  });

  test('hopscotch_holdingEachTargetPasses', () {
    final d = HopscotchDetector(difficulty: 3, random: Random(1));
    var t = Duration.zero;
    for (final o in d.sequence) {
      t = hold(d, o, t, const Duration(milliseconds: 400));
    }
    expect(d.progress.passed, isTrue);
  });

  test('hopscotch_briefTouchDoesNotCount', () {
    final d = HopscotchDetector(difficulty: 1, random: Random(2));
    hold(d, d.sequence.first, Duration.zero, const Duration(milliseconds: 200));
    expect(d.step, 0);
  });

  test('hopscotch_tooSlowRestarts', () {
    final d = HopscotchDetector(
      difficulty: 5,
      random: Random(3),
    ); // 1.5 s per step
    final sequence = [...d.sequence];
    var t = hold(
      d,
      sequence[0],
      Duration.zero,
      const Duration(milliseconds: 400),
    );
    expect(d.step, 1);
    // Wander in no particular orientation for 2 s.
    final end = t + const Duration(seconds: 2);
    while (t < end) {
      d.onAccel(const Vec3(5, 5, 5), t);
      t += const Duration(milliseconds: 50);
    }
    expect(d.step, 0);
    expect(d.sequence, sequence);
    expect(d.progress.value, 0);
  });

  test('wrong orientation does not advance', () {
    final d = HopscotchDetector(difficulty: 1, random: Random(4));
    final wrong = PhoneOrientation.values.firstWhere((o) => o != d.sequence[0]);
    hold(d, wrong, Duration.zero, const Duration(seconds: 1));
    expect(d.step, 0);
  });

  testWidgets('hopscotch widget passes when the motion follows the sequence', (
    tester,
  ) async {
    final motion = FakeMotionSource();
    var passed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [motionSourceProvider.overrideWithValue(motion)],
        child: MaterialApp(
          home: Scaffold(
            body: HopscotchChallenge(
              args: ChallengeArgs(
                difficulty: 1,
                random: Random(7),
                onPassed: () => passed++,
              ),
            ),
          ),
        ),
      ),
    );
    final sequence = HopscotchDetector(
      difficulty: 1,
      random: Random(7),
    ).sequence;
    for (final o in sequence) {
      for (var i = 0; i < 8; i++) {
        motion.accel.add(gravityFor(o));
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
    }
    await tester.pump();
    expect(passed, 1);
  });
}
