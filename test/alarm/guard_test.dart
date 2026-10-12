import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/pump_app.dart';

class FakeAuthenticator implements Authenticator {
  FakeAuthenticator(this.allow);

  final bool allow;
  int prompts = 0;

  @override
  Future<bool> confirm(String reason) async {
    prompts++;
    return allow;
  }
}

void main() {
  final monday0645 = DateTime(2026, 10, 12, 6, 45); // a Monday

  test('nextRing_repeatAndOneShot', () {
    expect(
      nextRing(Alarm(id: 1, hour: 7, minute: 0), monday0645),
      DateTime(2026, 10, 12, 7),
    );
    expect(
      nextRing(Alarm(id: 1, hour: 6, minute: 0), monday0645),
      DateTime(2026, 10, 13, 6),
    );
    expect(
      nextRing(Alarm(id: 1, hour: 7, minute: 0, repeatDays: {3}), monday0645),
      DateTime(2026, 10, 14, 7),
    );
    expect(
      nextRing(Alarm(id: 1, hour: 7, minute: 0, enabled: false), monday0645),
      isNull,
    );
  });

  test('needsGuard_within30Minutes', () {
    expect(needsGuard(Alarm(id: 1, hour: 7, minute: 15), monday0645), isTrue);
    expect(needsGuard(Alarm(id: 1, hour: 7, minute: 16), monday0645), isFalse);
    expect(
      needsGuard(Alarm(id: 1, hour: 7, minute: 0, enabled: false), monday0645),
      isFalse,
    );
  });

  Future<(FakeAlarmPlatform, FakeAuthenticator)> pump(
    WidgetTester tester, {
    required bool allow,
    int minute = 0,
  }) async {
    final fake = FakeAlarmPlatform(
      seed: [Alarm(id: 1, hour: 7, minute: minute)],
    );
    final auth = FakeAuthenticator(allow);
    await pumpApp(
      tester,
      fake,
      extraOverrides: [
        authenticatorProvider.overrideWithValue(auth),
        nowProvider.overrideWithValue(() => monday0645),
      ],
    );
    return (fake, auth);
  }

  testWidgets('toggleOff_guardedAlarm_denied_keepsEnabled', (tester) async {
    final (fake, auth) = await pump(tester, allow: false);
    await tester.tap(find.byKey(const Key('alarm-switch-1')));
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(fake.stored[1]!.enabled, isTrue);
  });

  testWidgets('toggleOff_guardedAlarm_allowed_disables', (tester) async {
    final (fake, _) = await pump(tester, allow: true);
    await tester.tap(find.byKey(const Key('alarm-switch-1')));
    await tester.pumpAndSettle();
    expect(fake.stored[1]!.enabled, isFalse);
  });

  testWidgets('toggleOff_unguarded_noPrompt', (tester) async {
    final (fake, auth) = await pump(tester, allow: false, minute: 59);
    await tester.tap(find.byKey(const Key('alarm-switch-1')));
    await tester.pumpAndSettle();
    expect(auth.prompts, 0);
    expect(fake.stored[1]!.enabled, isFalse);
  });

  testWidgets('swipeDelete_guarded_denied_keepsAlarm', (tester) async {
    final (fake, _) = await pump(tester, allow: false);
    await tester.drag(
      find.byKey(const Key('alarm-tile-1')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(fake.stored, hasLength(1));
    expect(find.byKey(const Key('alarm-tile-1')), findsOneWidget);
  });
}
