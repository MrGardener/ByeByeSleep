import 'dart:math';

import 'package:byebyesleep/alarm/estimate.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/app/ui_kit.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/clock.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/memory_grid/rule.dart';
import 'package:byebyesleep/challenges/memory_grid/widget.dart';
import 'package:byebyesleep/challenges/number_order/rule.dart';
import 'package:byebyesleep/challenges/number_order/widget.dart';
import 'package:byebyesleep/challenges/odd_one_out/rule.dart';
import 'package:byebyesleep/challenges/odd_one_out/widget.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:byebyesleep/challenges/retype/sentence.dart';
import 'package:byebyesleep/challenges/retype/widget.dart';
import 'package:byebyesleep/challenges/shake_it/counter.dart';
import 'package:byebyesleep/challenges/shake_it/widget.dart';
import 'package:byebyesleep/challenges/word_unscramble/widget.dart';
import 'package:byebyesleep/challenges/word_unscramble/word.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_motion_source.dart';

const _new = [
  ChallengeId.memoryGrid,
  ChallengeId.shakeIt,
  ChallengeId.retype,
  ChallengeId.numberOrder,
  ChallengeId.wordUnscramble,
  ChallengeId.oddOneOut,
];

void main() {
  group('memory grid', () {
    test('bigger grid and more tiles with difficulty', () {
      final easy = MemoryPattern.forDifficulty(1, Random(1));
      final hard = MemoryPattern.forDifficulty(5, Random(1));
      expect(easy.size, 3);
      expect(easy.lit, hasLength(3));
      expect(hard.size, 5);
      expect(hard.lit, hasLength(8));
      for (final p in [easy, hard]) {
        expect(p.lit.every((c) => c >= 0 && c < p.size * p.size), isTrue);
      }
      expect(hard.showFor, greaterThan(easy.showFor));
    });

    test('tapping every lit tile is right; any other tile is wrong', () {
      const p = MemoryPattern(3, {0, 4, 8});
      final a = p.attempt();
      expect(a.tap(0), isTrue);
      expect(a.tap(0), isTrue); // tapping again changes nothing
      expect(a.state, GridState.going);
      a
        ..tap(8)
        ..tap(4);
      expect(a.state, GridState.right);
      final b = p.attempt();
      expect(b.tap(1), isFalse);
      expect(b.state, GridState.wrong);
      b.tap(0);
      expect(b.state, GridState.wrong); // stays wrong
    });
  });

  group('shake it', () {
    Vec3 g(double m) => Vec3(0, 0, m);

    test('20 shakes at difficulty 1, 60 at 5', () {
      expect(ShakeCounter.forDifficulty(1).target, 20);
      expect(ShakeCounter.forDifficulty(5).target, 60);
    });

    test('a peak counts once; it must calm down before the next', () {
      final c = ShakeCounter(3);
      var t = Duration.zero;
      void feed(double m) {
        t += const Duration(milliseconds: 50);
        c.onAccel(g(m), t);
      }

      feed(9.8);
      feed(25);
      feed(27); // same peak
      feed(18); // not calm enough to re-arm
      feed(26);
      expect(c.count, 1);
      feed(10);
      feed(25);
      expect(c.count, 2);
      feed(9);
      feed(30);
      expect(c.passed, isTrue);
      expect(c.progress, 1);
    });

    test('gentle movement and buzzing too fast do not count', () {
      final c = ShakeCounter(20);
      for (var i = 0; i < 40; i++) {
        c.onAccel(g(i.isEven ? 8 : 16), Duration(milliseconds: 50 * i));
      }
      expect(c.count, 0);
      // Peaks 20 ms apart: sensor noise, not a shake.
      c.onAccel(g(25), const Duration(seconds: 3));
      c.onAccel(g(5), const Duration(milliseconds: 3010));
      c.onAccel(g(25), const Duration(milliseconds: 3020));
      expect(c.count, 1);
    });
  });

  group('retype', () {
    test('case and punctuation do not matter; words do', () {
      const r = Retype("Good morning, it's a bright new day!");
      expect(r.accepts("good morning it's a bright new day"), isTrue);
      expect(r.accepts('GOOD MORNING  its a bright new day.'), isTrue);
      expect(r.accepts('Good morning, it’s a bright new day'), isTrue);
      expect(r.accepts('Good morning, its a bright day!'), isFalse);
      expect(r.accepts('Good mornin, its a bright new day!'), isFalse);
      expect(r.wordsRight('good morning it is'), 2);
    });

    test('longer sentences with difficulty', () {
      int words(String s) => s.split(' ').length;
      final easy = Retype.random(Random(1), 1).sentence;
      final hard = Retype.random(Random(1), 5).sentence;
      expect(words(hard), greaterThan(words(easy) + 3));
      for (final tier in morningSentences) {
        for (final s in tier) {
          expect(normaliseSentence(s), isNotEmpty);
        }
      }
    });
  });

  group('number order', () {
    test('9 numbers at difficulty 1, 25 at 5, each in its own cell', () {
      for (final (d, n) in [(1, 9), (5, 25)]) {
        final b = NumberBoard.random(Random(d), d);
        expect(b.count, n);
        expect(b.cellOf.toSet(), hasLength(n));
        expect(b.cellOf.every((c) => c < b.cols * b.rows), isTrue);
        expect(b.cols * b.rows, greaterThan(n)); // some gaps: scattered
      }
    });

    test('ascending taps finish; a wrong tap restarts from 1', () {
      final b = NumberBoard.random(Random(1), 1, count: 4);
      expect(b.tap(1), NumberTap.right);
      expect(b.tap(2), NumberTap.right);
      expect(b.tap(4), NumberTap.wrong);
      expect(b.next, 1);
      for (final n in [1, 2, 3]) {
        expect(b.tap(n), NumberTap.right);
      }
      expect(b.tap(4), NumberTap.done);
      expect(b.done, isTrue);
    });
  });

  group('word unscramble', () {
    test('longer words with difficulty; tiles never show the answer', () {
      for (var d = 1; d <= 5; d++) {
        for (var seed = 0; seed < 20; seed++) {
          final u = Unscramble.random(Random(seed), d);
          expect(u.word.length, d + 3);
          expect(u.tiles.join(), isNot(u.word));
          expect([...u.tiles]..sort(), u.word.split('')..sort());
        }
      }
    });

    test('pick, undo, right and wrong', () {
      final u = Unscramble.random(Random(1), 1, word: 'wake');
      int tile(String c) => [
        for (var i = 0; i < u.tiles.length; i++)
          if (u.tiles[i] == c && !u.picked.contains(i)) i,
      ].first;
      u
        ..pick(tile('w'))
        ..pick(tile('k'));
      expect(u.guess, 'wk');
      u.undo();
      u
        ..pick(tile('a'))
        ..pick(tile('k'));
      expect(u.state, WordState.going);
      u.pick(tile('e'));
      expect(u.state, WordState.right);
      u.clear();
      expect(u.guess, '');
      u
        ..pick(tile('e'))
        ..pick(tile('k'))
        ..pick(tile('a'))
        ..pick(tile('w'));
      expect(u.state, WordState.wrong);
      u.pick(0); // full: ignored
      expect(u.guess, 'ekaw');
    });
  });

  group('odd one out', () {
    test('bigger grid and a subtler difference with difficulty', () {
      final easy = OddOneOut(1, Random(1)), hard = OddOneOut(5, Random(1));
      expect(hard.size, greaterThan(easy.size));
      expect(hard.angleDegrees, lessThan(easy.angleDegrees));
      expect(easy.round.odd, lessThan(easy.size * easy.size));
    });

    test('three right in a row passes; a miss starts the count again', () {
      final o = OddOneOut(3, Random(1));
      expect(o.tap(o.round.odd), isTrue);
      expect(o.tap(o.round.odd), isTrue);
      expect(o.tap((o.round.odd + 1) % (o.size * o.size)), isFalse);
      expect(o.streak, 0);
      for (var i = 0; i < 3; i++) {
        o.tap(o.round.odd);
      }
      expect(o.passed, isTrue);
    });
  });

  group('screens', () {
    late int passed;
    late Duration clock;
    late FakeMotionSource motion;

    Future<void> pump(
      WidgetTester tester,
      Widget Function(ChallengeArgs) build, {
      Map<String, Object?> params = const {},
      int difficulty = 1,
    }) async {
      passed = 0;
      clock = Duration.zero;
      motion = FakeMotionSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            challengeClockProvider.overrideWithValue(() => clock),
            motionSourceProvider.overrideWithValue(motion),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: build(
                  ChallengeArgs(
                    difficulty: difficulty,
                    random: Random(1),
                    params: params,
                    onPassed: () => passed++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('memory grid: wrong tile replays, right tiles pass', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => MemoryGridChallenge(args: a),
        params: const {
          'tiles': [0, 4, 8],
        },
      );
      expect(find.textContaining('Watch'), findsOneWidget);
      await tester.tap(find.byKey(const Key('memory-0')));
      await tester.pump();
      expect(passed, 0); // taps ignored while it shows
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('memory-1')));
      await tester.pump();
      expect(find.textContaining('Wrong'), findsOneWidget);
      expect(passed, 0);
      await tester.pump(const Duration(seconds: 5));
      for (final c in [8, 0, 4]) {
        await tester.tap(find.byKey(Key('memory-$c')));
        await tester.pump();
      }
      expect(passed, 1);
    });

    testWidgets('memory grid tiles are at least 48 dp at difficulty 5', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, (a) => MemoryGridChallenge(args: a), difficulty: 5);
      final size = tester.getSize(find.byKey(const Key('memory-0')));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shake it: gentle moves do not count, hard shakes pass', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => ShakeItChallenge(args: a),
        params: const {'count': 3},
      );
      Future<void> sample(double m) async {
        clock += const Duration(milliseconds: 100);
        motion.accel.add(Vec3(0, 0, m));
        await tester.pump();
      }

      for (var i = 0; i < 10; i++) {
        await sample(i.isEven ? 8 : 15);
      }
      expect(find.text('0 / 3'), findsOneWidget);
      expect(passed, 0);
      for (var i = 0; i < 3; i++) {
        await sample(28);
        await sample(9);
      }
      expect(passed, 1);
    });

    testWidgets('shake it: a broken sensor asks for another challenge', (
      tester,
    ) async {
      var unavailable = 0;
      motion = FakeMotionSource();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [motionSourceProvider.overrideWithValue(motion)],
          child: MaterialApp(
            home: Scaffold(
              body: ShakeItChallenge(
                args: ChallengeArgs(
                  difficulty: 1,
                  random: Random(1),
                  onPassed: () {},
                  onUnavailable: () => unavailable++,
                ),
              ),
            ),
          ),
        ),
      );
      motion.accel.addError(StateError('no sensor'));
      await tester.pump();
      expect(unavailable, 1);
    });

    testWidgets('retype: a typo does not pass, the sentence does', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => RetypeChallenge(args: a),
        params: const {'sentence': 'Rise and shine!'},
      );
      expect(find.text('Rise and shine!'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('retype-field')), 'rise an');
      await tester.pump();
      expect(passed, 0);
      await tester.enterText(
        find.byKey(const Key('retype-field')),
        'Rise and shin',
      );
      await tester.pump();
      expect(passed, 0);
      await tester.enterText(
        find.byKey(const Key('retype-field')),
        'rise and shine',
      );
      await tester.pump();
      expect(passed, 1);
    });

    testWidgets('number order: a wrong tap restarts, ascending passes', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => NumberOrderChallenge(args: a),
        params: const {'count': 4},
      );
      Future<void> tap(int n) async {
        await tester.tap(find.byKey(Key('number-$n')));
        await tester.pump();
      }

      await tap(1);
      await tap(3);
      expect(find.textContaining('Start again'), findsOneWidget);
      expect(passed, 0);
      for (final n in [1, 2, 3, 4]) {
        await tap(n);
      }
      expect(passed, 1);
    });

    testWidgets('number order: 25 numbers fit with 48 dp targets', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, (a) => NumberOrderChallenge(args: a), difficulty: 5);
      for (var n = 1; n <= 25; n++) {
        final s = tester.getSize(find.byKey(Key('number-$n')));
        expect(s.shortestSide, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('word unscramble: wrong order clears, right word passes', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => WordUnscrambleChallenge(args: a),
        params: const {'word': 'wake'},
      );
      Future<void> spell(String w) async {
        for (final c in w.split('')) {
          // First unused tile with that letter.
          await tester.tap(find.byKey(Key('tile-$c')).first);
          await tester.pump();
        }
      }

      await spell('kawe');
      expect(find.textContaining('Not quite'), findsOneWidget);
      expect(passed, 0);
      await spell('wa');
      await tester.tap(find.byKey(const Key('unscramble-undo')));
      await tester.pump();
      await spell('ake');
      expect(passed, 1);
    });

    testWidgets('each fits a small ring-screen panel at levels 1 and 5', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final id in _new) {
        for (final level in [1, 5]) {
          await pump(
            tester,
            (a) => SizedBox(
              width: 328,
              height: 440,
              child: Center(child: definitionFor(id).build(a)),
            ),
            difficulty: level,
          );
          expect(tester.takeException(), isNull, reason: '$id at $level');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 5));
        }
      }
    });

    testWidgets('odd one out: a miss resets, three finds pass', (tester) async {
      await pump(
        tester,
        (a) => OddOneOutChallenge(args: a),
        params: const {'odd': 2},
      );
      Future<void> tap(int i) async {
        await tester.tap(find.byKey(Key('odd-$i')));
        await tester.pump();
      }

      await tap(2);
      await tap(2);
      await tap(0); // wrong
      expect(find.text('0 / 3'), findsOneWidget);
      expect(passed, 0);
      await tap(2);
      await tap(2);
      await tap(2);
      expect(passed, 1);
    });
  });

  test('registered with icons, estimates and what they need', () {
    for (final id in _new) {
      final d = definitionFor(id);
      expect(d.title, isNotEmpty);
      expect(d.instructions, isNotEmpty);
      expect(challengeIcon(id), isNotNull);
      final e = estimateStop([StageConfig(id)], 0);
      expect(e.low, greaterThan(Duration.zero));
      expect(e.high, greaterThan(e.low));
      // Harder takes longer.
      expect(
        estimateStop([StageConfig(id, difficulty: 5)], 0).high,
        greaterThan(estimateStop([StageConfig(id, difficulty: 1)], 0).high),
      );
      final needs = id == ChallengeId.shakeIt
          ? const {SensorKind.accelerometer}
          : const <SensorKind>{};
      for (var level = 1; level <= 5; level++) {
        expect(d.requires(level), needs);
      }
    }
    expect(
      resolveStage(const StageConfig(ChallengeId.shakeIt), const {}).challenge,
      ChallengeId.brokenCalculator,
    );
    expect(
      StageConfig.fromJson(const {'challenge': 'oddOneOut'}).challenge,
      ChallengeId.oddOneOut,
    );
  });
}
