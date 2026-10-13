import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:byebyesleep/challenges/core/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../challenges/photo_match_test.dart'
    show FakeCamera, MemoryPhotoStore;
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
    await tester.ensureVisible(find.byKey(const Key('pause-dropdown')));
    await tester.pumpAndSettle();
    expect(find.text('No pause'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pause-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15 seconds').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored.values.single.pauseSeconds, 15);
  });

  Future<void> reveal(WidgetTester tester, Key key) async {
    await tester.scrollUntilVisible(
      find.byKey(key),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('seriesSectionCreatesASeriesWithAPreview', (tester) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('series-switch'));
    await tester.tap(find.byKey(const Key('series-switch')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('series-preview'));
    expect(
      tester.widget<Text>(find.byKey(const Key('series-preview'))).data,
      contains(','),
    );
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    final main = fake.stored.values.firstWhere((a) => a.parentId == null);
    expect(main.series, isNotNull);
    expect(fake.stored.length, main.series!.count);
  });

  testWidgets('splitWarnsThenMakesIndependentAlarms', (tester) async {
    final main = Alarm(
      id: 4,
      hour: 17,
      minute: 0,
      series: const SeriesConfig(count: 3, everyMinutes: 5),
    );
    final fake = FakeAlarmPlatform(seed: [main, ...seriesChildren(main)]);
    await pumpApp(tester, fake);
    await tester.tap(find.text('17:00'));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('series-split'));
    await tester.tap(find.byKey(const Key('series-split')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('split-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('split-confirm')));
    await tester.pumpAndSettle();
    expect(fake.stored.values.every((a) => a.parentId == null), isTrue);
    expect(fake.stored[4]!.series, isNull);
    expect(find.byKey(const Key('series-child-401')), findsNothing);
    expect(find.byKey(const Key('alarm-switch-401')), findsOneWidget);
  });

  testWidgets('reminderWithPhotoAndCaptionAsAReminderOnlyAlarm', (
    tester,
  ) async {
    final fake = FakeAlarmPlatform();
    final store = MemoryPhotoStore();
    await pumpApp(
      tester,
      fake,
      extraOverrides: [
        photoCameraProvider.overrideWithValue(() => FakeCamera([7])),
        photoStoreProvider.overrideWithValue(store),
      ],
    );
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('reminder-photo'));
    await tester.tap(find.byKey(const Key('reminder-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-shutter')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('reminder-caption'));
    await tester.enterText(
      find.byKey(const Key('reminder-caption')),
      'Passport',
    );
    await reveal(tester, const Key('reminder-only'));
    await tester.tap(find.byKey(const Key('reminder-only')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-stage')), findsNothing);
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    final saved = fake.stored.values.single;
    expect(saved.stages, isEmpty);
    expect(saved.reminder?.caption, 'Passport');
    expect(saved.reminder?.photoPath, store.files.keys.single);
  });

  testWidgets('reminderOnlyNeedsAReminder', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform());
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('reminder-only'));
    final sw = tester.widget<SwitchListTile>(
      find.byKey(const Key('reminder-only')),
    );
    expect(sw.onChanged, isNull);
  });

  testWidgets('awakeCheckIsOffByDefaultAndConfigurable', (tester) async {
    final fake = FakeAlarmPlatform();
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await reveal(tester, const Key('followup-dropdown'));
    expect(find.text('Off'), findsOneWidget);
    await tester.tap(find.byKey(const Key('followup-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After 10 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored.values.single.followUpMinutes, 10);
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
