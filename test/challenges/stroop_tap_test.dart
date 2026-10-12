import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/stroop_tap/detector.dart';
import 'package:byebyesleep/challenges/stroop_tap/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stroop_wordNeverMatchesInk', () {
    final d = StroopDetector(difficulty: 5, random: Random(1));
    for (var i = 0; i < 200; i++) {
      expect(d.word, isNot(d.ink.name.toUpperCase()));
      expect(d.choices, contains(d.ink));
      d.choose(d.choices.firstWhere((c) => c != d.ink)); // wrong, keeps going
    }
  });

  test('stroop_correctStreakPasses', () {
    for (var difficulty = 1; difficulty <= 5; difficulty++) {
      final d = StroopDetector(difficulty: difficulty, random: Random(2));
      var taps = 0;
      while (!d.progress.passed) {
        d.choose(d.ink);
        taps++;
      }
      expect(taps, difficulty + 2);
    }
  });

  test('stroop_wrongResetsStreak', () {
    final d = StroopDetector(difficulty: 1, random: Random(3));
    d.choose(d.ink);
    d.choose(d.ink);
    expect(d.progress.value, closeTo(2 / 3, 1e-9));
    d.choose(d.choices.firstWhere((c) => c != d.ink));
    expect(d.progress.value, 0);
  });

  test('colour set and shuffling follow difficulty', () {
    expect(
      StroopDetector(difficulty: 1, random: Random(4)).choices,
      hasLength(4),
    );
    expect(
      StroopDetector(difficulty: 4, random: Random(4)).choices,
      hasLength(5),
    );
    final easy = StroopDetector(difficulty: 2, random: Random(5));
    final order = [...easy.choices];
    easy.choose(easy.ink);
    expect(easy.choices, order);
  });

  testWidgets('stroopWidget_tapInkColorAdvances', (tester) async {
    var passed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StroopChallenge(
            args: ChallengeArgs(
              difficulty: 1,
              random: Random(6),
              onPassed: () => passed++,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      final word = tester.widget<Text>(find.byKey(const Key('stroop-word')));
      final ink = InkColor.values.firstWhere(
        (c) => inkColorValue(c) == word.style!.color,
      );
      await tester.tap(find.byKey(Key('stroop-${ink.name}')));
      await tester.pump();
    }
    expect(passed, 1);
  });
}
