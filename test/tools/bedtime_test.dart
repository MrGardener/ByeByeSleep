import 'package:byebyesleep/tools/bedtime.dart';
import 'package:byebyesleep/app/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBedtime implements BedtimePlatform {
  BedtimeSettings current = const BedtimeSettings();
  final sets = <BedtimeSettings>[];
  var quietAllowed = false;
  var accessOpened = 0;

  @override
  Future<void> openQuietHoursAccess() async => accessOpened++;

  @override
  Future<BedtimeSettings> get() async => current;

  @override
  Future<BedtimeSettings> set(BedtimeSettings s) async {
    sets.add(s);
    return current = BedtimeSettings(
      enabled: s.enabled,
      sleepMinutes: s.sleepMinutes,
      windDownMinutes: s.windDownMinutes,
      quietHours: s.quietHours,
      quietHoursAllowed: quietAllowed,
      quietHoursSupported: true,
      nextAt: s.enabled ? DateTime(2026, 10, 14, 22, 30) : null,
    );
  }
}

void main() {
  test('sleep goals and labels', () {
    expect(sleepGoals.first, 360);
    expect(sleepGoals.last, 600);
    expect(sleepLabel(480), '8 h');
    expect(sleepLabel(450), '7 h 30 min');
  });

  testWidgets('settings: turn on the bedtime reminder and pick a goal', (
    tester,
  ) async {
    final fake = FakeBedtime();
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bedtimePlatformProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsWidgets);
    await tester.tap(find.byKey(const Key('bedtime-switch')));
    await tester.pumpAndSettle();
    expect(fake.sets.last.enabled, isTrue);
    expect(find.textContaining('Next reminder 22:30'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bedtime-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 h 30 min').last);
    await tester.pumpAndSettle();
    expect(fake.sets.last.sleepMinutes, 450);
  });

  testWidgets('settings: wind-down reminder and quiet hours', (tester) async {
    final fake = FakeBedtime()
      ..current = const BedtimeSettings(
        enabled: true,
        quietHoursSupported: true,
      );
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bedtimePlatformProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('bedtime-wind-down')));
    await tester.tap(find.byKey(const Key('bedtime-wind-down')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 min before').last);
    await tester.pumpAndSettle();
    expect(fake.sets.last.windDownMinutes, 30);
    // Quiet hours need Do Not Disturb access first.
    await tester.ensureVisible(find.byKey(const Key('bedtime-quiet')));
    await tester.tap(find.byKey(const Key('bedtime-quiet')));
    await tester.pumpAndSettle();
    expect(fake.accessOpened, 1);
    expect(fake.sets.last.quietHours, isFalse);
    fake.quietAllowed = true;
    fake.current = const BedtimeSettings(
      enabled: true,
      windDownMinutes: 30,
      quietHoursAllowed: true,
      quietHoursSupported: true,
    );
    await tester.tap(find.byKey(const Key('bedtime-quiet')));
    await tester.pumpAndSettle();
    expect(fake.sets.last.quietHours, isTrue);
  });

  testWidgets('settings: no native bedtime (iPhone) hides the section', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bedtimePlatformProvider.overrideWithValue(UnsupportedBedtime()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bedtime-switch')), findsNothing);
  });
}
