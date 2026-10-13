import 'dart:io';

import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/challenges/core/watch.dart';
import 'package:byebyesleep/watch_setup/watch_settings.dart';
import 'package:byebyesleep/watch_setup/watch_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../challenges/watch_test.dart' show FakeWatch;
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';
import '../support/memory_watch_store.dart';

void main() {
  test('settings round-trip through the file', () async {
    final dir = Directory.systemTemp.createTempSync('watch');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FileWatchSettingsStore(() async => dir);
    expect((await store.load()).choice, WatchChoice.unknown);
    await store.save(
      const WatchSettings(
        choice: WatchChoice.verified,
        sensors: {SensorKind.heartRate, SensorKind.watchSteps},
      ),
    );
    final back = await store.load();
    expect(back.choice, WatchChoice.verified);
    expect(back.sensors, {SensorKind.heartRate, SensorKind.watchSteps});
  });

  group('capabilities', () {
    Future<Set<SensorKind>> caps(WatchSettings s, {bool connected = true}) {
      final c = ProviderContainer(
        overrides: [
          motionSourceProvider.overrideWithValue(FakeMotionSource()),
          envSensorProvider.overrideWithValue(FakeEnvSensors()),
          extraCapabilitiesProvider.overrideWithValue(const []),
          watchSettingsStoreProvider.overrideWithValue(
            MemoryWatchStore()..saved = s,
          ),
          watchSourceProvider.overrideWithValue(
            FakeWatch(connected: connected),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c.read(deviceCapabilitiesProvider.future);
    }

    test('no watch sensors until the watch is set up and verified', () async {
      expect(
        (await caps(const WatchSettings())).intersection(watchKinds),
        isEmpty,
      );
      expect(
        (await caps(const WatchSettings(choice: WatchChoice.none)))
            .intersection(watchKinds),
        isEmpty,
      );
    });

    test(
      'only the verified sensors, and only while the watch answers',
      () async {
        const s = WatchSettings(
          choice: WatchChoice.verified,
          sensors: {SensorKind.heartRate},
        );
        expect((await caps(s)).intersection(watchKinds), {
          SensorKind.heartRate,
        });
        expect(
          (await caps(s, connected: false)).intersection(watchKinds),
          isEmpty,
        );
      },
    );
  });

  group('setup screen', () {
    late MemoryWatchStore store;
    late FakeWatch watch;

    Future<void> pump(WidgetTester tester) async {
      store = MemoryWatchStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            watchSettingsStoreProvider.overrideWithValue(store),
            watchSourceProvider.overrideWithValue(watch),
          ],
          child: const MaterialApp(home: WatchSetupScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('no watch: remembered, watch features stay hidden', (
      tester,
    ) async {
      watch = FakeWatch();
      await pump(tester);
      expect(find.textContaining('Do you have a smartwatch'), findsOneWidget);
      await tester.tap(find.byKey(const Key('watch-no')));
      await tester.pumpAndSettle();
      expect(store.saved.choice, WatchChoice.none);
    });

    testWidgets('yes: install steps, then a live test unlocks what works', (
      tester,
    ) async {
      watch = FakeWatch();
      await pump(tester);
      await tester.tap(find.byKey(const Key('watch-yes')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Install'), findsWidgets);
      await tester.tap(find.byKey(const Key('watch-test')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('check-connected-done')), findsOneWidget);
      expect(find.byKey(const Key('watch-save')), findsNothing);
      watch.readings$.add(const HeartRateReading(70));
      watch.readings$.add(const MotionReading([1, 2]));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('check-heartRate-done')), findsOneWidget);
      expect(find.byKey(const Key('check-watchSteps-todo')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('watch-save')));
      await tester.tap(find.byKey(const Key('watch-save')));
      await tester.pumpAndSettle();
      expect(store.saved.choice, WatchChoice.verified);
      expect(store.saved.sensors, {
        SensorKind.heartRate,
        SensorKind.watchMotion,
      });
    });

    testWidgets('watch not found: says so, nothing is unlocked', (
      tester,
    ) async {
      watch = FakeWatch(connected: false);
      await pump(tester);
      await tester.tap(find.byKey(const Key('watch-yes')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('watch-test')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('check-connected-todo')), findsOneWidget);
      expect(find.textContaining('not found'), findsOneWidget);
      expect(store.saved.choice, WatchChoice.unknown);
    });
  });
}
