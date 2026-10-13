import 'dart:async';
import 'dart:math';

import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/heart_rate.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/heart_rate/detector.dart';
import 'package:byebyesleep/challenges/heart_rate/widget.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHeartRate implements HeartRateSource {
  FakeHeartRate({this.watch = true});

  final bool watch;
  final readings = StreamController<int>.broadcast();
  var listening = false;

  @override
  Future<bool> available() async => watch;

  @override
  Stream<int> get bpm {
    listening = true;
    return readings.stream;
  }
}

Duration s(num v) => Duration(milliseconds: (v * 1000).round());

void main() {
  test('baseline is the median of the first five readings', () {
    final g = HeartRateGoal(difficulty: 3);
    for (final (i, bpm) in [62, 70, 64, 200, 66].indexed) {
      g.add(bpm, s(i));
    }
    expect(g.baseline, 66);
    expect(g.goal, 91); // 66 + 10 + 5×3
  });

  test('the goal is at least 90 bpm', () {
    final g = HeartRateGoal(difficulty: 1);
    for (var i = 0; i < 5; i++) {
      g.add(55, s(i));
    }
    expect(g.goal, 90);
  });

  test('15 s in total at the goal passes, not necessarily in one go', () {
    final g = HeartRateGoal(difficulty: 1);
    var t = 0.0;
    void feed(int bpm, double seconds) {
      for (var x = 0.0; x < seconds; x += 1) {
        g.add(bpm, s(t));
        t += 1;
      }
    }

    feed(60, 5); // baseline 60 → goal 90
    feed(100, 10);
    feed(80, 5); // dipped: keeps what was earned
    expect(g.passed, isFalse);
    feed(100, 6);
    expect(g.passed, isTrue);
  });

  test('zero and silly readings are ignored', () {
    final g = HeartRateGoal(difficulty: 1);
    g.add(0, s(0));
    g.add(260, s(1));
    expect(g.baseline, isNull);
    expect(g.progress, 0);
  });

  group('challenge', () {
    late int passed;
    late int unavailable;

    Future<void> pump(WidgetTester tester, FakeHeartRate source) async {
      passed = 0;
      unavailable = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heartRateSourceProvider.overrideWithValue(source),
            heartRateClockProvider.overrideWithValue(
              () => Duration(seconds: source.readings.hashCode % 1),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HeartRateChallenge(
                args: ChallengeArgs(
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

    testWidgets('passes after the heart rate stays up', (tester) async {
      final source = FakeHeartRate();
      var t = Duration.zero;
      passed = 0;
      unavailable = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            heartRateSourceProvider.overrideWithValue(source),
            heartRateClockProvider.overrideWithValue(() => t),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HeartRateChallenge(
                args: ChallengeArgs(
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
      Future<void> feed(int bpm, int seconds) async {
        for (var i = 0; i < seconds; i++) {
          source.readings.add(bpm);
          await tester.pump();
          t += const Duration(seconds: 1);
        }
      }

      await feed(62, 5);
      await tester.pump(); // the last reading lands after its frame
      expect(find.textContaining('90'), findsWidgets); // the goal
      await feed(110, 17);
      expect(passed, 1);
      expect(find.byKey(const Key('heart-bpm')), findsOneWidget);
    });

    testWidgets('no watch: unavailable at once', (tester) async {
      await pump(tester, FakeHeartRate(watch: false));
      await tester.pump();
      expect(unavailable, 1);
    });

    testWidgets('a watch that never sends a reading: unavailable', (
      tester,
    ) async {
      await pump(tester, FakeHeartRate());
      await tester.pump(const Duration(seconds: 31));
      expect(unavailable, 1);
    });
  });

  test('without a watch the stage is replaced', () {
    expect(
      resolveStage(
        const StageConfig(ChallengeId.heartRate),
        const {},
      ).challenge,
      ChallengeId.brokenCalculator,
    );
    expect(
      resolveStage(const StageConfig(ChallengeId.heartRate), const {
        SensorKind.heartRate,
      }).challenge,
      ChallengeId.heartRate,
    );
  });
}
