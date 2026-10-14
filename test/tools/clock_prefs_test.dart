import 'package:byebyesleep/tools/clock_prefs.dart';
import 'package:byebyesleep/tools/world_clock.dart';
import 'package:byebyesleep/app/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('12 and 24 hour formats', () {
    expect(formatHm(6, 5, use24: true), '06:05');
    expect(formatHm(6, 5, use24: false), '6:05 AM');
    expect(formatHm(0, 30, use24: false), '12:30 AM');
    expect(formatHm(12, 0, use24: false), '12:00 PM');
    expect(formatHm(23, 59, use24: false), '11:59 PM');
    expect(uses24(TimeFormat.system, systemUses24: false), isFalse);
    expect(uses24(TimeFormat.h24, systemUses24: false), isTrue);
    expect(uses24(TimeFormat.h12, systemUses24: true), isFalse);
  });

  test('prefs round-trip, home city included', () {
    const p = ClockPrefs(
      face: ClockFace.analog,
      hours: TimeFormat.h12,
      showSeconds: false,
      fahrenheit: true,
      home: City(
        'Madrid',
        'Spain',
        'Europe/Madrid',
        latitude: 40.42,
        longitude: -3.7,
      ),
      homeClockWhenAway: false,
    );
    final back = ClockPrefs.fromJson(p.toJson());
    expect(back.face, ClockFace.analog);
    expect(back.hours, TimeFormat.h12);
    expect(back.showSeconds, isFalse);
    expect(back.fahrenheit, isTrue);
    expect(back.home!.zone, 'Europe/Madrid');
    expect(back.homeClockWhenAway, isFalse);
    expect(ClockPrefs.fromJson(const {}).face, ClockFace.digital);
  });

  testWidgets('settings: clock style, 24 h, °F and the home time zone', (
    tester,
  ) async {
    final store = MemoryClockPrefsStore();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockPrefsStoreProvider.overrideWithValue(store),
          httpGetProvider.overrideWithValue((_) async => '{}'),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('clock-face-analog')));
    await tester.pumpAndSettle();
    expect(store.saved.face, ClockFace.analog);
    await tester.tap(find.byKey(const Key('clock-hours-h24')));
    await tester.pumpAndSettle();
    expect(store.saved.hours, TimeFormat.h24);
    await tester.tap(find.byKey(const Key('clock-fahrenheit')));
    await tester.pumpAndSettle();
    expect(store.saved.fahrenheit, isTrue);
    await tester.ensureVisible(find.byKey(const Key('clock-home')));
    await tester.tap(find.byKey(const Key('clock-home')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('world-search')), 'madrid');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-Madrid@Europe/Madrid')));
    await tester.pumpAndSettle();
    expect(store.saved.home!.zone, 'Europe/Madrid');
    expect(find.textContaining('Madrid'), findsWidgets);
  });
}
