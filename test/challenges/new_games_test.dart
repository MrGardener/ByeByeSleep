import 'dart:math';
import 'dart:typed_data';

import 'package:byebyesleep/challenges/colour_hunt/colour.dart';
import 'package:byebyesleep/challenges/pulse_code/code.dart';
import 'package:byebyesleep/challenges/time_sense/rule.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/colour_hunt/widget.dart';
import 'package:byebyesleep/challenges/core/camera.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/core/clock.dart';
import 'package:byebyesleep/challenges/pulse_code/widget.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:byebyesleep/challenges/time_sense/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Camera that "photographs" plain colours, in turn.
class ColourCamera implements PhotoCamera {
  ColourCamera(this.colours);

  final List<(int, int, int)> colours;

  @override
  Future<void> init() async {}

  @override
  Widget preview() => const SizedBox(height: 10);

  @override
  Future<Uint8List> capture() async {
    final (r, g, b) = colours.removeAt(0);
    final im = img.Image(width: 60, height: 80);
    img.fill(im, color: img.ColorRgb8(r, g, b));
    return img.encodeJpg(im);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('time sense', () {
    test('within the tolerance passes; too early or late does not', () {
      final r = TimeSense.forDifficulty(1); // 20 s, ±3 s
      expect(r.target, const Duration(seconds: 20));
      expect(r.accepts(const Duration(seconds: 22)), isTrue);
      expect(r.accepts(const Duration(milliseconds: 17000)), isTrue);
      expect(r.accepts(const Duration(milliseconds: 16900)), isFalse);
      expect(r.accepts(const Duration(seconds: 24)), isFalse);
    });

    test('harder means longer and stricter', () {
      final easy = TimeSense.forDifficulty(1),
          hard = TimeSense.forDifficulty(5);
      expect(hard.target, greaterThan(easy.target));
      expect(hard.tolerance, lessThan(easy.tolerance));
    });

    test('feedback says how far off', () {
      final r = TimeSense.forDifficulty(1);
      expect(r.feedback(const Duration(seconds: 26)), 'Too slow by 6.0 s');
      expect(r.feedback(const Duration(seconds: 14)), 'Too fast by 6.0 s');
    });
  });

  group('pulse code', () {
    test('random codes get longer with difficulty', () {
      expect(PulseCode.random(Random(1), 1).pulses.length, 3);
      expect(PulseCode.random(Random(1), 5).pulses.length, 7);
    });

    test('typing it back: right passes, a wrong pulse fails at once', () {
      const code = PulseCode([Pulse.short, Pulse.long, Pulse.short]);
      final a = code.attempt()
        ..add(Pulse.short)
        ..add(Pulse.long);
      expect(a.state, AttemptState.going);
      a.add(Pulse.short);
      expect(a.state, AttemptState.right);
      final b = code.attempt()..add(Pulse.long);
      expect(b.state, AttemptState.wrong);
    });

    test('the flash timeline: long is three times a short', () {
      final t = const PulseCode([Pulse.short, Pulse.long]).timeline();
      expect(t.map((s) => s.on), [true, false, true, false]);
      expect(t[0].length * 3, t[2].length);
    });
  });

  group('colour hunt', () {
    Uint8List photo(int r, int g, int b, {bool centreOnly = false}) {
      final im = img.Image(width: 120, height: 160);
      img.fill(
        im,
        color: img.ColorRgb8(
          centreOnly ? 128 : r,
          centreOnly ? 128 : g,
          centreOnly ? 128 : b,
        ),
      );
      if (centreOnly) {
        img.fillRect(
          im,
          x1: 30,
          y1: 40,
          x2: 90,
          y2: 120,
          color: img.ColorRgb8(r, g, b),
        );
      }
      return img.encodeJpg(im, quality: 90);
    }

    test('a clearly red centre is red, also in dim light', () {
      expect(centreColour(photo(200, 30, 30)), HuntColour.red);
      expect(centreColour(photo(90, 15, 15)), HuntColour.red);
      expect(centreColour(photo(40, 150, 50)), HuntColour.green);
      expect(centreColour(photo(30, 60, 200)), HuntColour.blue);
      expect(centreColour(photo(230, 210, 40)), HuntColour.yellow);
    });

    test('only the centre counts', () {
      expect(
        centreColour(photo(30, 60, 200, centreOnly: true)),
        HuntColour.blue,
      );
    });

    test('grey, white and black are no colour', () {
      expect(centreColour(photo(128, 128, 128)), isNull);
      expect(centreColour(photo(250, 250, 250)), isNull);
      expect(centreColour(photo(10, 10, 10)), isNull);
      expect(centreColour(Uint8List.fromList([1, 2, 3])), isNull);
    });
  });

  group('screens', () {
    late int passed;
    late Duration clock;

    Future<void> pump(
      WidgetTester tester,
      Widget Function(ChallengeArgs) build, {
      Map<String, Object?> params = const {},
      List<Object> overrides = const [],
    }) async {
      passed = 0;
      clock = Duration.zero;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            challengeClockProvider.overrideWithValue(() => clock),
            ...overrides.cast(),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: build(
                ChallengeArgs(
                  difficulty: 1,
                  random: Random(1),
                  params: params,
                  onPassed: () => passed++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('time sense: too fast, then right', (tester) async {
      await pump(tester, (a) => TimeSenseChallenge(args: a));
      expect(find.textContaining('20 seconds'), findsWidgets);
      await tester.tap(find.byKey(const Key('time-start')));
      await tester.pump();
      clock = const Duration(seconds: 12);
      await tester.tap(find.byKey(const Key('time-stop')));
      await tester.pump();
      expect(find.text('Too fast by 8.0 s'), findsOneWidget);
      expect(passed, 0);
      await tester.tap(find.byKey(const Key('time-start')));
      await tester.pump();
      clock = const Duration(seconds: 33);
      await tester.tap(find.byKey(const Key('time-stop')));
      await tester.pump();
      expect(passed, 1);
    });

    testWidgets('pulse code: watch, tap back, pass', (tester) async {
      await pump(
        tester,
        (a) => PulseCodeChallenge(args: a),
        params: const {'code': 'SLS'},
      );
      expect(find.byKey(const Key('pulse-short')), findsNothing); // watching
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('pulse-short')));
      await tester.tap(find.byKey(const Key('pulse-long')));
      await tester.tap(find.byKey(const Key('pulse-short')));
      await tester.pump();
      expect(passed, 1);
    });

    testWidgets('pulse code: a wrong pulse shows the code again', (
      tester,
    ) async {
      await pump(
        tester,
        (a) => PulseCodeChallenge(args: a),
        params: const {'code': 'SLS'},
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byKey(const Key('pulse-long')));
      await tester.pump();
      expect(find.textContaining('Wrong'), findsOneWidget);
      expect(find.byKey(const Key('pulse-short')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const Key('pulse-short')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('colour hunt: wrong colour, then the right one', (
      tester,
    ) async {
      final camera = ColourCamera([(40, 150, 50), (200, 30, 30)]);
      await pump(
        tester,
        (a) => ColourHuntChallenge(args: a),
        params: const {'colour': 'red'},
        overrides: [photoCameraProvider.overrideWithValue(() => camera)],
      );
      expect(find.textContaining('red'), findsWidgets);
      await tester.tap(find.byKey(const Key('colour-check')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('green'), findsOneWidget);
      expect(passed, 0);
      await tester.tap(find.byKey(const Key('colour-check')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(passed, 1);
    });
  });

  test('registered, with what they need', () {
    expect(definitionFor(ChallengeId.timeSense).requires(3), isEmpty);
    expect(definitionFor(ChallengeId.pulseCode).requires(3), isEmpty);
    expect(
      resolveStage(
        const StageConfig(ChallengeId.colourHunt),
        const {},
      ).challenge,
      ChallengeId.brokenCalculator,
    );
  });
}
