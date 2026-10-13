import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/game/progress_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../game/quest_screen_test.dart' show MemoryStore;
import '../support/fake_alarm_platform.dart';
import '../support/pump_app.dart';

/// Pixel 10 Pro in portrait with 3-button navigation: the back / home /
/// switch bar covers the bottom 48 dp, the status bar the top 40 dp.
const _size = Size(412, 915);
const _navBar = 48.0;
const _ratio = 2.625;

void main() {
  Future<FakeAlarmPlatform> pumpPhone(
    WidgetTester tester, {
    List<Alarm> alarms = const [],
  }) async {
    tester.view
      ..devicePixelRatio = _ratio
      ..physicalSize = _size * _ratio
      ..padding = const FakeViewPadding(
        top: 40 * _ratio,
        bottom: _navBar * _ratio,
      )
      ..viewPadding = const FakeViewPadding(
        top: 40 * _ratio,
        bottom: _navBar * _ratio,
      );
    addTearDown(tester.view.reset);
    final fake = FakeAlarmPlatform(seed: alarms);
    await pumpApp(
      tester,
      fake,
      extraOverrides: [
        progressStoreProvider.overrideWithValue(MemoryStore()),
        deviceCapabilitiesProvider.overrideWith(
          (_) async => SensorKind.values.toSet(),
        ),
      ],
    );
    return fake;
  }

  /// Fails when [finder]'s widget reaches into the navigation bar.
  void clearOfNavBar(WidgetTester tester, Finder finder, String what) {
    final bottom = tester.getRect(finder).bottom;
    expect(
      bottom,
      lessThanOrEqualTo(_size.height - _navBar),
      reason: '$what ends at $bottom, under the navigation bar',
    );
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await tester.pumpAndSettle();
  }

  testWidgets('alarm list: add button and tabs above the nav bar', (
    tester,
  ) async {
    await pumpPhone(tester);
    clearOfNavBar(tester, find.byKey(const Key('add-alarm')), 'Add alarm');
    clearOfNavBar(tester, find.byKey(const Key('tab-practice')), 'Tabs');
  });

  testWidgets('alarm editor: the last controls are above the nav bar', (
    tester,
  ) async {
    await pumpPhone(tester);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('reminder-only')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await scrollToEnd(tester);
    clearOfNavBar(tester, find.byKey(const Key('reminder-only')), 'Reminder');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-stage')));
    await tester.pumpAndSettle();
    clearOfNavBar(tester, find.byKey(const Key('add-stage')), 'Add challenge');
  });

  testWidgets('challenge picker: the last challenge is above the nav bar', (
    tester,
  ) async {
    await pumpPhone(tester);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('add-stage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-stage')));
    await tester.pumpAndSettle();
    final sheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    final last = find.byKey(const Key('pick-compass'));
    await tester.scrollUntilVisible(last, 200, scrollable: sheet);
    await tester.drag(sheet, const Offset(0, -2000)); // to the very end
    await tester.pumpAndSettle();
    expect(last, findsOneWidget);
    clearOfNavBar(tester, last, 'Last challenge in the picker');
  });

  testWidgets('practice and quest lists end above the nav bar', (tester) async {
    await pumpPhone(tester);
    await tester.tap(find.byKey(const Key('tab-practice')));
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    clearOfNavBar(tester, find.byType(ListTile).last, 'Practice list');
    await tester.tap(find.byKey(const Key('tab-quest')));
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
    clearOfNavBar(tester, find.byType(Card).last, 'Quest list');
  });
}
