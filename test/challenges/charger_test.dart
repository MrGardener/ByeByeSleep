import 'dart:async';
import 'dart:math';

import 'package:byebyesleep/challenges/charger/detector.dart';
import 'package:byebyesleep/challenges/charger/widget.dart';
import 'package:byebyesleep/challenges/core/battery.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCharge implements ChargeSource {
  FakeCharge(this.pluggedNow);

  bool pluggedNow;
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> isPlugged() async => pluggedNow;

  @override
  Stream<bool> get plugged => controller.stream;
}

void main() {
  test('charger_plugInPasses', () {
    final d = ChargerDetector(pluggedAtStart: false);
    expect(d.needsUnplug, isFalse);
    expect(d.onPlugged(false).passed, isFalse);
    expect(d.onPlugged(true).passed, isTrue);
  });

  test('charger_pluggedAtStartNeedsReplug', () {
    final d = ChargerDetector(pluggedAtStart: true);
    expect(d.needsUnplug, isTrue);
    expect(d.onPlugged(true).passed, isFalse);
    expect(d.onPlugged(false).passed, isFalse);
    expect(d.needsUnplug, isFalse);
    expect(d.onPlugged(true).passed, isTrue);
  });

  testWidgets('chargerWidget_textAsksToUnplugFirst', (tester) async {
    final charge = FakeCharge(true);
    var passed = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chargeSourceProvider.overrideWithValue(charge)],
        child: MaterialApp(
          home: Scaffold(
            body: ChargerChallenge(
              args: ChallengeArgs(
                difficulty: 2,
                random: Random(1),
                onPassed: () => passed++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Unplug'), findsOneWidget);
    charge.controller.add(false);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Unplug'), findsNothing);
    charge.controller.add(true);
    await tester.pump();
    await tester.pump();
    expect(passed, 1);
  });
}
