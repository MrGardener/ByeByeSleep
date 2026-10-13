import 'package:byebyesleep/challenges/core/battery.dart';
import 'package:byebyesleep/game/worlds/battery_oracle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLevel implements BatteryLevelSource {
  FakeLevel(this.value);
  int value;
  int reads = 0;

  @override
  Future<int> level() async {
    reads++;
    return value;
  }
}

void main() {
  group('tolerance', () {
    test('9% accepts 0–34', () {
      expect(oracleRange(9), (low: 0, high: 34));
      expect(oracleAccepts(34, 9), isTrue);
      expect(oracleAccepts(0, 9), isTrue);
      expect(oracleAccepts(35, 9), isFalse);
    });

    test('100% accepts 75–100', () {
      expect(oracleRange(100), (low: 75, high: 100));
      expect(oracleAccepts(75, 100), isTrue);
      expect(oracleAccepts(74, 100), isFalse);
    });

    test('90% accepts 65–100', () {
      expect(oracleRange(90), (low: 65, high: 100));
    });
  });

  group('world', () {
    late FakeLevel battery;
    late List<String> uiModes;
    var passed = 0;

    setUp(() {
      battery = FakeLevel(50);
      passed = 0;
      uiModes = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
              uiModes.add(call.arguments as String);
            }
            return null;
          });
    });

    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      ProviderScope(
        overrides: [batteryLevelProvider.overrideWithValue(battery)],
        child: MaterialApp(
          home: Scaffold(body: BatteryOracleWorld(onPassed: () => passed++)),
        ),
      ),
    );

    Future<void> guess(WidgetTester tester, String text) async {
      await tester.enterText(find.byKey(const Key('oracle-guess')), text);
      await tester.tap(find.byKey(const Key('oracle-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('out-of-range input is rejected without reading', (
      tester,
    ) async {
      await pump(tester);
      await guess(tester, '150');
      expect(find.text('Enter a number from 0 to 100'), findsOneWidget);
      expect(battery.reads, 0);
      expect(passed, 0);
    });

    testWidgets('level is read when the guess is submitted', (tester) async {
      await pump(tester);
      battery.value = 80;
      await guess(tester, '70');
      expect(battery.reads, 1);
      expect(passed, 1);
      expect(find.textContaining('80%'), findsOneWidget);
    });

    testWidgets('a miss shows the real level and allows another try', (
      tester,
    ) async {
      await pump(tester);
      battery.value = 9;
      await guess(tester, '35');
      expect(passed, 0);
      expect(find.textContaining('9%'), findsOneWidget);
      expect(find.textContaining('0–34'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      battery.value = 10;
      await guess(tester, '20');
      expect(passed, 1);
    });

    testWidgets('status bar hidden while playing, restored after', (
      tester,
    ) async {
      await pump(tester);
      expect(uiModes, ['SystemUiMode.immersiveSticky']);
      await tester.pumpWidget(const SizedBox());
      expect(uiModes.last, 'SystemUiMode.edgeToEdge');
    });
  });
}
