import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_alarm_platform.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('preflightBanner_listsMissingPermissions', (tester) async {
    final fake = FakeAlarmPlatform(
      permissionStatus: const PermissionStatus({
        PermissionKind.exactAlarm: true,
        PermissionKind.notifications: false,
      }),
    );
    await pumpApp(tester, fake);
    expect(find.byKey(const Key('preflight-banner')), findsOneWidget);
    expect(find.byKey(const Key('fix-exactAlarm')), findsNothing);
    await tester.tap(find.byKey(const Key('fix-notifications')));
    expect(fake.calls.last, 'openSettings:notifications');
  });

  testWidgets('preflightBanner_hiddenWhenAllGranted', (tester) async {
    await pumpApp(tester, FakeAlarmPlatform());
    expect(find.byKey(const Key('preflight-banner')), findsNothing);
  });
}
