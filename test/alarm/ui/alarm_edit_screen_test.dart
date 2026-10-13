import 'package:byebyesleep/alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_alarm_platform.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('addFlowCreatesAlarm', (tester) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-chip-1')));
    await tester.enterText(find.byKey(const Key('label-field')), 'Work');
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored, hasLength(1));
    expect(fake.stored.values.single.repeatDays, {1});
    expect(fake.stored.values.single.label, 'Work');
    expect(find.text('Work'), findsOneWidget); // back on the list
  });

  testWidgets('pauseBetweenStagesIsOffByDefaultAndConfigurable', (
    tester,
  ) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('pause-dropdown')),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('No pause'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pause-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 seconds').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored.values.single.pauseSeconds, 15);
  });

  testWidgets('editFlowUpdatesExistingAlarm', (tester) async {
    final fake = FakeAlarmPlatform(
      seed: [
        Alarm(id: 4, hour: 7, minute: 0, repeatDays: {1}),
      ],
    );
    await pumpApp(tester, fake);
    await tester.tap(find.text('07:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-chip-1'))); // unselect Monday
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored.keys, [4]);
    expect(fake.stored[4]!.repeatDays, isEmpty);
  });

  testWidgets('doubleTapSaveSavesOnceAndPopsOnce', (tester) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.tap(find.byKey(const Key('save-alarm')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('upsert')), hasLength(1));
    expect(
      find.byKey(const Key('add-alarm')),
      findsOneWidget,
    ); // list still there
  });

  testWidgets('saveFailureShowsErrorAndStays', (tester) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    fake.failWith = PlatformException(code: 'x');
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(find.text('Could not save the alarm. Try again.'), findsOneWidget);
    expect(find.byKey(const Key('save-alarm')), findsOneWidget);
  });
}
