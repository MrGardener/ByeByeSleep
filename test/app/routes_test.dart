import 'package:byebyesleep/alarm/ui/alarm_list_screen.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/game/practice_screen.dart';
import 'package:byebyesleep/game/progress_store.dart';
import 'package:byebyesleep/game/quest_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game/quest_screen_test.dart' show MemoryStore;
import '../support/fake_alarm_platform.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('unknown route falls back to alarm list', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform(), initialRoute: '/nope');
    expect(find.byType(AlarmListScreen), findsOneWidget);
  });

  testWidgets('home tabs switch between alarms, Sensor Quest and Practice', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeAlarmPlatform(),
      extraOverrides: [
        progressStoreProvider.overrideWithValue(MemoryStore()),
        deviceCapabilitiesProvider.overrideWith(
          (_) async => SensorKind.values.toSet(),
        ),
      ],
    );
    // One tab per tool, at the bottom of the home screen.
    await tester.tap(find.byKey(const Key('tab-quest')));
    await tester.pumpAndSettle();
    expect(find.byType(QuestScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-practice')));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-alarms')));
    await tester.pumpAndSettle();
    expect(find.byType(AlarmListScreen), findsOneWidget);
  });

  testWidgets('the clock tab has clock, timer and stopwatch', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform());
    await tester.tap(find.byKey(const Key('tab-clock')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('clock-time')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tool-stopwatch')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('sw-add')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tool-timer')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(); // the timer loads its saved state
    expect(find.byKey(const Key('timer-add')), findsOneWidget);
    // Back to alarms so the screens' tickers stop.
    await tester.tap(find.byKey(const Key('tab-alarms')));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('settings → smartwatch opens the watch setup', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform());
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Not set up'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-watch')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do you have a smartwatch'), findsOneWidget);
  });

  testWidgets('practice keeps watch challenges in their own section', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeAlarmPlatform(),
      extraOverrides: [
        progressStoreProvider.overrideWithValue(MemoryStore()),
        deviceCapabilitiesProvider.overrideWith(
          (_) async => SensorKind.values.toSet(),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('tab-practice')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('practice-watch-setup')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('watch-section')), findsOneWidget);
    expect(find.text('Get your heart going'), findsNothing);
  });
}
