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
}
