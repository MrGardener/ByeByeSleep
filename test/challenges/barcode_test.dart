import 'dart:math';

import 'package:byebyesleep/challenges/barcode/setup.dart';
import 'package:byebyesleep/challenges/barcode/widget.dart';
import 'package:byebyesleep/challenges/core/barcode_scanner.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scanner that "reads" whatever code the test taps.
class FakeScanner {
  ValueChanged<String>? onCode;

  Widget build(ValueChanged<String> onCode) {
    this.onCode = onCode;
    return const SizedBox(key: Key('fake-scanner'), height: 10);
  }
}

Widget host(FakeScanner scanner, Widget child) => ProviderScope(
  overrides: [barcodeScannerProvider.overrideWithValue(scanner.build)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  var passed = 0;
  setUp(() => passed = 0);

  Future<FakeScanner> run(WidgetTester tester) async {
    final scanner = FakeScanner();
    await tester.pumpWidget(
      host(
        scanner,
        BarcodeChallenge(
          args: ChallengeArgs(
            difficulty: 2,
            random: Random(1),
            onPassed: () => passed++,
            params: const {'code': '4006381333931'},
          ),
        ),
      ),
    );
    await tester.pump();
    return scanner;
  }

  testWidgets('barcode_rightCodePasses', (tester) async {
    final scanner = await run(tester);
    scanner.onCode!('4006381333931');
    await tester.pump();
    expect(passed, 1);
    scanner.onCode!('4006381333931');
    await tester.pump();
    expect(passed, 1);
  });

  testWidgets('barcode_wrongCodeShowsMessage', (tester) async {
    final scanner = await run(tester);
    scanner.onCode!('123');
    await tester.pump();
    expect(find.text("That's a different barcode."), findsOneWidget);
    expect(passed, 0);
  });

  testWidgets('barcodeSetup_savesCode', (tester) async {
    final scanner = FakeScanner();
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      host(
        scanner,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                saved = await setupBarcode(context, const {}),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    scanner.onCode!('4006381333931');
    await tester.pump();
    await tester.tap(find.byKey(const Key('setup-save')));
    await tester.pumpAndSettle();
    expect(saved, {'code': '4006381333931'});
  });
}
