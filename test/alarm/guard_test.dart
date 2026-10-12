import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/guard.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
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

/// Authenticator whose prompt ends with a [LocalAuthException] of [code].
LocalAuthAuthenticator failingWith(LocalAuthExceptionCode code) =>
    LocalAuthAuthenticator(
      isSupported: () async => true,
      authenticate: (_) async => throw LocalAuthException(code: code),
    );

class ThrowingAuthenticator implements Authenticator {
  @override
  Future<bool> confirm(String reason) async => throw StateError('boom');
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

  test('cancelled prompt counts as "no"', () async {
    final auth = failingWith(LocalAuthExceptionCode.userCanceled);
    expect(await auth.confirm('x'), isFalse);
  });

  test('a phone without any lock is not blocked', () async {
    final auth = failingWith(LocalAuthExceptionCode.noCredentialsSet);
    expect(await auth.confirm('x'), isTrue);
  });

  testWidgets('authenticator error keeps the alarm and the switch usable', (
    tester,
  ) async {
    final fake = FakeAlarmPlatform(seed: [Alarm(id: 1, hour: 7, minute: 0)]);
    await pumpApp(
      tester,
      fake,
      extraOverrides: [
        authenticatorProvider.overrideWithValue(ThrowingAuthenticator()),
        nowProvider.overrideWithValue(() => monday0645),
      ],
    );
    await tester.tap(find.byKey(const Key('alarm-switch-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(fake.stored[1]!.enabled, isTrue);
  });

  test('weakens: later ring, fewer days, other stages, disabled', () {
    final a = Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1, 2});
    expect(weakens(a, a, monday0645), isFalse);
    expect(weakens(a, a.copyWith(repeatDays: {2}), monday0645), isTrue);
    expect(weakens(a, a.copyWith(hour: 8), monday0645), isTrue);
    expect(weakens(a, a.copyWith(minute: 0, hour: 6), monday0645), isTrue);
    expect(weakens(a, a.copyWith(enabled: false), monday0645), isTrue);
    expect(
      weakens(
        a,
        a.copyWith(
          stages: const [StageConfig(ChallengeId.stroopTap, difficulty: 1)],
        ),
        monday0645,
      ),
      isTrue,
    );
    expect(weakens(a, a.copyWith(label: 'Gym'), monday0645), isFalse);
  });

  testWidgets('editing away today of an imminent alarm needs confirmation', (
    tester,
  ) async {
    final fake = FakeAlarmPlatform(
      seed: [
        Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1, 2}),
      ],
    );
    final auth = FakeAuthenticator(false);
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      fake,
      extraOverrides: [
        authenticatorProvider.overrideWithValue(auth),
        nowProvider.overrideWithValue(() => monday0645),
      ],
    );
    await tester.tap(find.text('07:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-chip-1'))); // drop Monday
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(auth.prompts, 1);
    expect(fake.stored[1]!.repeatDays, {1, 2});
  });
}
