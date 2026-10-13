import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/nfc.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/game/worlds/compass_temple.dart';
import 'package:byebyesleep/game/worlds/ghost_hide.dart';
import 'package:byebyesleep/game/worlds/labyrinth.dart';
import 'package:byebyesleep/game/worlds/rune_hunt.dart';
import 'package:byebyesleep/game/worlds/sky_tower.dart';
import 'package:byebyesleep/game/worlds/solar_garden.dart';
import 'package:byebyesleep/game/worlds/world_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../challenges/nfc_tag_test.dart' show FakeNfc;
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';

void main() {
  late FakeEnvSensors env;
  late FakeMotionSource motion;
  late FakeNfc nfc;
  var clock = Duration.zero;
  var passed = 0;
  var unavailable = 0;

  setUp(() {
    env = FakeEnvSensors();
    motion = FakeMotionSource();
    nfc = FakeNfc();
    clock = Duration.zero;
    passed = 0;
    unavailable = 0;
  });

  final args = WorldArgs(
    onPassed: () => passed++,
    onUnavailable: () => unavailable++,
  );

  Future<void> pump(WidgetTester tester, Widget world) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        envSensorProvider.overrideWithValue(env),
        motionSourceProvider.overrideWithValue(motion),
        nfcReaderProvider.overrideWithValue(nfc),
        gameClockProvider.overrideWithValue(() => clock),
      ],
      child: MaterialApp(home: Scaffold(body: world)),
    ),
  );

  testWidgets('Solar Garden passes after 10 s of bright light', (tester) async {
    await pump(tester, SolarGardenWorld(args: args));
    env.luxController.add(400);
    await tester.pump();
    for (var i = 0; i < 51; i++) {
      clock += const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(passed, 1);
    expect(find.text('In full bloom!'), findsOneWidget);
  });

  testWidgets('Solar Garden stops growing while the app is in the background', (
    tester,
  ) async {
    await pump(tester, SolarGardenWorld(args: args));
    env.luxController.add(400);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    for (var i = 0; i < 60; i++) {
      clock += const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(passed, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Labyrinth with a silent accelerometer is unavailable', (
    tester,
  ) async {
    await pump(tester, LabyrinthWorld(args: args));
    await tester.pump(const Duration(seconds: 3));
    expect(unavailable, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a silent sensor reports the world unavailable', (tester) async {
    await pump(tester, GhostHideWorld(args: args));
    await tester.pump(const Duration(seconds: 3));
    expect(unavailable, 1);
  });

  testWidgets('Ghost Hide asks to uncover first', (tester) async {
    await pump(tester, GhostHideWorld(args: args));
    env.proximityController.add(true);
    await tester.pump();
    expect(find.text('Uncover the top of the phone.'), findsOneWidget);
    env.proximityController.add(false);
    await tester.pump();
    await tester.pump(); // the event lands after the first frame
    expect(find.text('The ghost is wandering…'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stop the timers
  });

  testWidgets('Sky Tower passes after climbing a floor', (tester) async {
    await pump(tester, SkyTowerWorld(args: args));
    Future<void> feed(double hPa, int seconds) async {
      for (var i = 0; i < seconds * 10; i++) {
        clock += const Duration(milliseconds: 100);
        env.pressureController.add(hPa);
        await tester.pump();
      }
    }

    await feed(1000, 4);
    await feed(999.6, 4);
    expect(passed, 1);
  });

  testWidgets('Rune Hunt passes after three different tags', (tester) async {
    await pump(tester, RuneHuntWorld(args: args));
    await tester.pump();
    for (final id in ['A1', 'A1', 'B2', 'C3']) {
      nfc.controller.add(id);
      await tester.pump();
    }
    expect(passed, 1);
  });

  testWidgets('Compass Temple lights runes as the phone faces them', (
    tester,
  ) async {
    await pump(tester, CompassTempleWorld(args: args));
    // Flat phone: gravity +z; field pointing north (+y) and down.
    motion.accel.add(const Vec3(0, 0, 9.8));
    motion.mag.add(const Vec3(0, 20, -40));
    await tester.pump();
    expect(find.textContaining('Rune 1 of 4'), findsOneWidget);
    expect(unavailable, 0);
    await tester.pumpWidget(const SizedBox()); // cancel the watchdog
  });
}
