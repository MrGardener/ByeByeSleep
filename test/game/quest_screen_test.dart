import 'package:byebyesleep/challenges/core/battery.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/game/practice_screen.dart';
import 'package:byebyesleep/game/progress_store.dart';
import 'package:byebyesleep/game/quest.dart';
import 'package:byebyesleep/game/quest_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/challenge_solvers.dart';

class MemoryStore implements ProgressStore {
  Set<World> saved = {};

  @override
  Future<Set<World>> load() async => saved;

  @override
  Future<void> save(Set<World> completed) async => saved = completed;
}

class FixedLevel implements BatteryLevelSource {
  @override
  Future<int> level() async => 60;
}

void main() {
  late MemoryStore store;

  setUp(() {
    store = MemoryStore();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Set<SensorKind>? caps,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressStoreProvider.overrideWithValue(store),
          batteryLevelProvider.overrideWithValue(FixedLevel()),
          deviceCapabilitiesProvider.overrideWith(
            (_) async => caps ?? SensorKind.values.toSet(),
          ),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder status(World w) => find.byKey(Key('world-${w.name}-status'));

  testWidgets('fresh start: Battery Oracle open, Labyrinth locked', (
    tester,
  ) async {
    await pump(tester, const QuestScreen());
    expect(tester.widget<Text>(status(World.batteryOracle)).data, 'Play');
    expect(tester.widget<Text>(status(World.labyrinth)).data, 'Locked');
  });

  testWidgets('passing Battery Oracle saves it and opens Labyrinth', (
    tester,
  ) async {
    await pump(tester, const QuestScreen());
    await tester.tap(find.text(World.batteryOracle.title));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('oracle-guess')), '50');
    await tester.tap(find.byKey(const Key('oracle-submit')));
    await tester.pumpAndSettle();
    expect(find.text('World complete!'), findsOneWidget);
    await tester.tap(find.text('Back to the map'));
    await tester.pumpAndSettle();
    expect(store.saved, {World.batteryOracle});
    expect(tester.widget<Text>(status(World.batteryOracle)).data, 'Done');
    expect(tester.widget<Text>(status(World.labyrinth)).data, 'Play');
  });

  testWidgets('a world without its sensor says so', (tester) async {
    await pump(
      tester,
      const QuestScreen(),
      caps: SensorKind.values.toSet().difference({SensorKind.barometer}),
    );
    await tester.scrollUntilVisible(status(World.skyTower), 100);
    expect(
      tester.widget<Text>(status(World.skyTower)).data,
      'Not on this phone',
    );
  });

  testWidgets('practice runs a challenge and shows Passed', (tester) async {
    await pump(tester, const PracticeScreen());
    await tester.tap(find.text('Broken calculator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await solveCalculator(tester);
    await tester.pumpAndSettle();
    expect(find.text('Passed!'), findsOneWidget);
  });

  testWidgets('practice opens a challenge setup before its first run', (
    tester,
  ) async {
    await pump(tester, const PracticeScreen());
    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.text('Walk — setup'), findsOneWidget);
  });

  testWidgets('practice keeps permission-gated challenges playable', (
    tester,
  ) async {
    await pump(tester, const PracticeScreen(), caps: {SensorKind.battery});
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Photo match'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isTrue);
  });
}
