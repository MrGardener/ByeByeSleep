import 'package:byebyesleep/challenges/stroop_tap/detector.dart';
import 'package:byebyesleep/challenges/stroop_tap/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Evaluates "a + b", "a - b", "a × b" and "a × b + c".
int evaluateProblem(String problem) {
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

/// Solves every problem of the on-screen broken calculator.
Future<void> solveCalculator(WidgetTester tester) async {
  while (find.byKey(const Key('calc-problem')).evaluate().isNotEmpty) {
    final problem = tester.widget<Text>(find.byKey(const Key('calc-problem')));
    for (final ch in evaluateProblem(problem.data!).toString().split('')) {
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
  }
}

/// Taps the ink colour until the on-screen Stroop challenge is gone.
Future<void> solveStroop(WidgetTester tester) async {
  while (find.byKey(const Key('stroop-word')).evaluate().isNotEmpty) {
    final word = tester.widget<Text>(find.byKey(const Key('stroop-word')));
    final ink = InkColor.values.firstWhere(
      (c) => inkColorValue(c) == word.style!.color,
    );
    await tester.tap(find.byKey(Key('stroop-${ink.name}')));
    await tester.pump();
  }
}
