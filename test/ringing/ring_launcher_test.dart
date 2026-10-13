import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/ringing/ring_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';

void main() {
  Future<FakeAlarmPlatform> pump(
    WidgetTester tester, {
    required bool enabled,
    List<int> ringing = const [],
  }) async {
    final platform = FakeAlarmPlatform()..ringing = ringing;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmPlatformProvider.overrideWithValue(platform),
          ringLauncherEnabledProvider.overrideWithValue(enabled),
        ],
        child: MaterialApp(
          home: RingLauncher(
            ringScreen: (id, onFinished) => Scaffold(
              body: TextButton(
                onPressed: onFinished,
                child: Text('ringing $id'),
              ),
            ),
            child: const Text('home'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return platform;
  }

  testWidgets(
    'iPhone: opening the app while an alarm rings shows its challenges',
    (tester) async {
      final platform = await pump(tester, enabled: true, ringing: [3]);
      expect(find.text('ringing 3'), findsOneWidget);
      platform.ringing = [];
      await tester.tap(find.text('ringing 3'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets('iPhone: an alarm going off while the app is open is noticed', (
    tester,
  ) async {
    final platform = await pump(tester, enabled: true);
    expect(find.text('home'), findsOneWidget);
    platform.ringing = [5];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('ringing 5'), findsOneWidget);
  });

  testWidgets('Android opens its own ring screen: nothing is pushed', (
    tester,
  ) async {
    await pump(tester, enabled: false, ringing: [3]);
    expect(find.text('home'), findsOneWidget);
    expect(find.textContaining('ringing'), findsNothing);
  });

  testWidgets('iPhone: an alarm going off over the open app shows in 15 s', (
    tester,
  ) async {
    final platform = await pump(tester, enabled: true);
    platform.ringing = [7];
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();
    expect(find.text('ringing 7'), findsOneWidget);
  });
}
