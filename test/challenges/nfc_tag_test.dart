import 'dart:async';
import 'dart:math';

import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/nfc.dart';
import 'package:byebyesleep/challenges/nfc_tag/setup.dart';
import 'package:byebyesleep/challenges/nfc_tag/widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNfc implements NfcReader {
  final controller = StreamController<String>.broadcast();
  bool stopped = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<String> tagIds() => controller.stream;

  @override
  Future<void> stop() async => stopped = true;
}

Widget host(FakeNfc nfc, Widget child) => ProviderScope(
  overrides: [nfcReaderProvider.overrideWithValue(nfc)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  var passed = 0;
  setUp(() => passed = 0);

  Future<void> run(WidgetTester tester, FakeNfc nfc) async {
    await tester.pumpWidget(
      host(
        nfc,
        NfcChallenge(
          args: ChallengeArgs(
            difficulty: 2,
            random: Random(1),
            onPassed: () => passed++,
            params: const {'tagId': '04A1B2'},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('nfc_rightTagPasses', (tester) async {
    final nfc = FakeNfc();
    await run(tester, nfc);
    nfc.controller.add('04A1B2');
    await tester.pump();
    await tester.pump();
    expect(passed, 1);
  });

  testWidgets('nfc_wrongTagShowsMessage', (tester) async {
    final nfc = FakeNfc();
    await run(tester, nfc);
    nfc.controller.add('FFFFFF');
    await tester.pump();
    await tester.pump();
    expect(find.text("That's a different sticker."), findsOneWidget);
    expect(passed, 0);
  });

  testWidgets('nfcSetup_savesTagId', (tester) async {
    final nfc = FakeNfc();
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      host(
        nfc,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await setupNfc(context, const {}),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    nfc.controller.add('04A1B2');
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('setup-save')));
    await tester.pumpAndSettle();
    expect(saved, {'tagId': '04A1B2'});
    expect(nfc.stopped, isTrue);
  });

  test('tag ids are uppercase hex', () {
    expect(tagIdHex([4, 161, 178]), '04A1B2');
  });
}
