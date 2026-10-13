import 'dart:async';
import 'dart:math';

import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/core/watch.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:byebyesleep/challenges/watch/detectors.dart';
import 'package:byebyesleep/challenges/watch/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A watch driven by the test.
class FakeWatch implements WatchSource {
  FakeWatch({this.connected = true});

  final bool connected;
  final readings$ = StreamController<WatchReading>.broadcast();

  @override
  Future<bool> available() async => connected;

  @override
  Stream<WatchReading> get readings => readings$.stream;
}

/// One arm swing at 10 Hz: still, a peak of [peak] m/s², still.
List<double> swing({double peak = 18}) => [1, 6, peak, 9, 2, 1];

void main() {
  group('swings', () {
    test('each up-and-down swing counts once', () {
      final c = SwingCounter();
      for (var i = 0; i < 5; i++) {
        c.addAll(swing());
      }
      expect(c.swings, 5);
    });

    test('small wrist movements do not count', () {
      final c = SwingCounter();
      for (var i = 0; i < 20; i++) {
        c.addAll([1, 4, 7, 4, 1]);
      }
      expect(c.swings, 0);
    });

    test('shaking faster than real swings counts at most every 0.3 s', () {
      final c = SwingCounter();
      // 20 Hz jitter between 0 and 20 m/s² for 2 s (sampled at 10 Hz).
      for (var i = 0; i < 20; i++) {
        c.add(i.isEven ? 20 : 0);
      }
      expect(c.swings, lessThanOrEqualTo(7));
    });

    test('continuous swinging counts, it never needs a pause', () {
      // Window peaks (10 Hz) of an arm swinging without stopping, 1 s per
      // back-and-forth: large at both ends of the swing, never near zero
      // in between (reviewer's pendulum simulation: lowest 6–25 m/s²).
      for (final (low, high) in [(6.0, 22.0), (12.0, 30.0), (25.0, 45.0)]) {
        final c = SwingCounter();
        for (var i = 0; i < 100; i++) {
          final phase = sin(2 * pi * i / 10).abs(); // two peaks per second
          c.add(low + (high - low) * phase);
        }
        expect(c.swings, inInclusiveRange(15, 22), reason: '$low–$high');
      }
    });

    test('target grows with difficulty', () {
      expect(swingsFor(1), lessThan(swingsFor(5)));
    });
  });

  group('steps', () {
    test('counts steps from the first reading', () {
      final g = StepGoal(30);
      g.update(12); // the watch had already counted some
      g.update(30);
      expect(g.walked, 18);
      expect(g.passed, isFalse);
      g.update(42);
      expect(g.passed, isTrue);
    });

    test('the watch announces 0 steps, so the first step counts', () {
      final g = StepGoal(1);
      g.update(0);
      g.update(1);
      expect(g.passed, isTrue);
    });

    test('(old)', () {
      final g = StepGoal(30);
      g.update(12);
      g.update(30);
      expect(g.walked, 18);
      expect(g.passed, isFalse);
      g.update(42);
      expect(g.passed, isTrue);
    });
  });

  group('widgets', () {
    late FakeWatch watch;
    late int passed;
    late int unavailable;

    Future<void> pump(
      WidgetTester tester,
      Widget Function(ChallengeArgs) b,
    ) async {
      passed = 0;
      unavailable = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [watchSourceProvider.overrideWithValue(watch)],
          child: MaterialApp(
            home: Scaffold(
              body: b(
                ChallengeArgs(
                  difficulty: 1,
                  random: Random(1),
                  onPassed: () => passed++,
                  onUnavailable: () => unavailable++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('wrist workout passes after enough swings', (tester) async {
      watch = FakeWatch();
      await pump(tester, (a) => WatchSwingChallenge(args: a));
      for (var i = 0; i < swingsFor(1); i++) {
        watch.readings$.add(MotionReading(swing()));
        await tester.pump();
      }
      expect(passed, 1);
    });

    testWidgets('walk with your watch passes after the steps', (tester) async {
      watch = FakeWatch();
      await pump(tester, (a) => WatchStepsChallenge(args: a));
      watch.readings$.add(const StepsReading(0));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('0 of ${stepsFor(1)}'), findsOneWidget);
      watch.readings$.add(StepsReading(stepsFor(1)));
      await tester.pump();
      expect(passed, 1);
    });

    testWidgets('steps never arriving (only motion): falls back', (
      tester,
    ) async {
      watch = FakeWatch();
      await pump(tester, (a) => WatchStepsChallenge(args: a));
      for (var i = 0; i < 70; i++) {
        watch.readings$.add(const MotionReading([1, 2]));
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(unavailable, 1);
    });

    testWidgets('no watch: unavailable at once', (tester) async {
      watch = FakeWatch(connected: false);
      await pump(tester, (a) => WatchStepsChallenge(args: a));
      await tester.pump();
      expect(unavailable, 1);
    });
  });

  test('watch challenges are replaced when there is no watch', () {
    for (final id in [ChallengeId.watchSwing, ChallengeId.watchSteps]) {
      expect(
        resolveStage(StageConfig(id), const {}).challenge,
        ChallengeId.brokenCalculator,
      );
    }
    expect(
      resolveStage(const StageConfig(ChallengeId.watchSwing), const {
        SensorKind.watchMotion,
      }).challenge,
      ChallengeId.watchSwing,
    );
  });
}
