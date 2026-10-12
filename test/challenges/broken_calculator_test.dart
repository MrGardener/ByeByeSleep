import 'dart:math';

import 'package:byebyesleep/challenges/broken_calculator/detector.dart';
import 'package:byebyesleep/challenges/broken_calculator/widget.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates "a + b", "a - b", "a × b" and "a × b + c".
int evaluate(String problem) {
  final t = problem.split(' ');
  var v = int.parse(t[0]);
  for (var i = 1; i < t.length; i += 2) {
    final n = int.parse(t[i + 1]);
    v = switch (t[i]) {
      '+' => v + n,
      '-' => v - n,
      _ => v * n,
    };
  }
  return v;
}

/// Types [answer] by finding each digit on the current (moving) keypad.
void typeAnswer(BrokenCalculatorDetector d, int answer) {
  for (final ch in answer.toString().split('')) {
    d.press(d.keypad.indexOf(int.parse(ch)));
  }
}

void main() {
  test('calculator_solvesWithCorrectAnswer', () {
    for (var difficulty = 1; difficulty <= 5; difficulty++) {
      final d = BrokenCalculatorDetector(
        difficulty: difficulty,
        random: Random(difficulty),
      );
      var solved = 0;
      while (!d.progress.passed) {
        typeAnswer(d, evaluate(d.problem));
        d.submit();
        solved++;
        expect(solved, lessThanOrEqualTo(3));
      }
      expect(solved, [1, 2, 2, 3, 3][difficulty - 1]);
    }
  });

  test('calculator_keypadReshufflesAfterEachPress', () {
    final d = BrokenCalculatorDetector(difficulty: 2, random: Random(1));
    for (var i = 0; i < 20; i++) {
      final before = [...d.keypad];
      d.press(0);
      if (d.entry.length >= 6) d.backspace();
      expect(d.keypad, isNot(before));
      expect([...d.keypad]..sort(), List.generate(10, (i) => i));
    }
  });

  test('calculator_wrongAnswerGivesNewProblem', () {
    final d = BrokenCalculatorDetector(difficulty: 2, random: Random(2));
    final problem = d.problem;
    typeAnswer(d, evaluate(problem) + 1);
    final p = d.submit();
    expect(p.value, 0);
    expect(d.problem, isNot(problem));
    expect(d.entry, isEmpty);
  });

  test('calculator_ignoresInputAfterPass', () {
    final d = BrokenCalculatorDetector(difficulty: 1, random: Random(3));
    typeAnswer(d, evaluate(d.problem));
    expect(d.submit().passed, isTrue);
    expect(d.press(0).passed, isTrue);
    expect(d.backspace().passed, isTrue);
    expect(d.submit().passed, isTrue);
  });

  test('subtraction never goes negative', () {
    final d = BrokenCalculatorDetector(difficulty: 3, random: Random(4));
    for (var i = 0; i < 200; i++) {
      expect(evaluate(d.problem), greaterThanOrEqualTo(0));
      d.submit(); // wrong (empty) answer → new problem
    }
  });

  testWidgets('calculatorWidget_callsOnPassed', (tester) async {
    var passed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrokenCalculatorChallenge(
            args: ChallengeArgs(
              difficulty: 1,
              random: Random(5),
              onPassed: () => passed++,
            ),
          ),
        ),
      ),
    );
    final problem = tester.widget<Text>(find.byKey(const Key('calc-problem')));
    for (final ch in evaluate(problem.data!).toString().split('')) {
      final key = find.byWidgetPredicate(
        (w) =>
            w is FilledButton &&
            (w.key as ValueKey<String>?)?.value.startsWith('calc-key-') ==
                true &&
            ((w.child! as Text).data == ch),
      );
      await tester.tap(key);
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('calc-submit')));
    await tester.pump();
    expect(passed, 1);
  });
}
