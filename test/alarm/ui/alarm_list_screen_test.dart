import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_alarm_platform.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('listShowsAlarmsWithRepeatSummary', (tester) async {
    final fake = FakeAlarmPlatform(
      seed: [
        Alarm(id: 1, hour: 6, minute: 0, repeatDays: {1, 2, 3, 4, 5}),
        Alarm(id: 2, hour: 7, minute: 0),
        Alarm(id: 3, hour: 8, minute: 0, repeatDays: {1, 2, 3, 4, 5, 6, 7}),
        Alarm(id: 4, hour: 9, minute: 0, repeatDays: {6, 7}),
        Alarm(id: 5, hour: 10, minute: 0, repeatDays: {1, 3, 5}),
      ],
    );
    await pumpApp(tester, fake);
    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
    expect(find.text('Weekends'), findsOneWidget);
    expect(find.text('Mon, Wed, Fri'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);
  });

  testWidgets('listShowsHowLongEachAlarmTakesToTurnOff', (tester) async {
    final fake = FakeAlarmPlatform(
      seed: [
        Alarm(id: 1, hour: 6, minute: 0),
        Alarm(id: 2, hour: 7, minute: 0, stages: const []),
      ],
    );
    await pumpApp(tester, fake);
    expect(find.textContaining('min to turn off'), findsOneWidget);
    expect(find.text('Stops at once'), findsOneWidget);
  });

  testWidgets('seriesAlarmsAreNestedUnderTheirMainAlarm', (tester) async {
    final main = Alarm(
      id: 4,
      hour: 17,
      minute: 0,
      series: const SeriesConfig(count: 3, everyMinutes: 5),
    );
    final fake = FakeAlarmPlatform(
      seed: [Alarm(id: 1, hour: 17, minute: 7), main, ...seriesChildren(main)],
    );
    await pumpApp(tester, fake);
    // Order: the main alarm, its series, then the next alarm.
    final rows = tester
        .widgetList<Text>(find.byKey(const Key('alarm-time')))
        .map((t) => t.data)
        .toList();
    expect(rows, ['17:00', '17:05', '17:10', '17:07']);
    expect(find.byKey(const Key('series-child-401')), findsOneWidget);
    expect(find.text('Series of 3 · every 5 min'), findsOneWidget);
    // A series alarm has no switch of its own; tapping it edits the main one.
    expect(find.byKey(const Key('alarm-switch-401')), findsNothing);
    await tester.tap(find.byKey(const Key('series-child-401')));
    await tester.pumpAndSettle();
    expect(find.text('Edit alarm'), findsOneWidget);
    expect(find.text('17:00'), findsOneWidget);
  });

  testWidgets('toggleSwitchDisablesAlarm', (tester) async {
    final fake = FakeAlarmPlatform(seed: [Alarm(id: 1, hour: 7, minute: 0)]);
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('alarm-switch-1')));
    await tester.pumpAndSettle();
    expect(fake.stored[1]!.enabled, isFalse);
  });

  testWidgets('swipeDeletesAlarm', (tester) async {
    final fake = FakeAlarmPlatform(seed: [Alarm(id: 1, hour: 7, minute: 0)]);
    await pumpApp(tester, fake);
    await tester.drag(
      find.byKey(const Key('alarm-tile-1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(fake.stored, isEmpty);
  });

  testWidgets('listReloadsOnResume', (tester) async {
    final fake = FakeAlarmPlatform(seed: [Alarm(id: 1, hour: 7, minute: 0)]);
    await pumpApp(tester, fake);
    // The native engine disables a one-shot alarm after it rang.
    fake.stored[1] = fake.stored[1]!.copyWith(enabled: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    final sw = tester.widget<Switch>(find.byKey(const Key('alarm-switch-1')));
    expect(sw.value, isFalse);
  });

  testWidgets('emptyStateIsShown', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform());
    expect(find.text('No alarms yet'), findsOneWidget);
  });
}
