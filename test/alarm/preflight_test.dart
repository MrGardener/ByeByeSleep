import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:byebyesleep/alarm/preflight.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/pump_app.dart';

void main() {
  test('preflight_listsMissingSetupAndPermissions', () {
    final alarm = Alarm(
      id: 1,
      hour: 7,
      minute: 0,
      stages: const [
        StageConfig(ChallengeId.stroopTap),
        StageConfig(ChallengeId.photoMatch),
        StageConfig(ChallengeId.walkSteps),
      ],
    );
    final problems = preflightProblems(
      alarm,
      const PermissionStatus({
        PermissionKind.notifications: false,
        PermissionKind.activityRecognition: false,
        PermissionKind.camera: false,
      }),
    );
    expect(problems, [
      'Notifications permission is off.',
      'Stage 2 (Photo match) needs setup.',
      'Camera permission is off (needed by stage 2).',
      'Physical activity permission is off (needed by stage 3).',
    ]);
  });

  test('preflight_emptyWhenAllGood', () {
    expect(
      preflightProblems(
        Alarm(id: 1, hour: 7, minute: 0),
        PermissionStatus.unknownAllGranted,
      ),
      isEmpty,
    );
  });

  testWidgets('editScreen_showsPreflightDialog', (tester) async {
    final fake = FakeAlarmPlatform(
      permissionStatus: const PermissionStatus({
        PermissionKind.notifications: false,
      }),
    );
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preflight-dialog')), findsOneWidget);
    expect(
      find.textContaining('Notifications permission is off.'),
      findsOneWidget,
    );
    expect(fake.stored, isEmpty);
    await tester.tap(find.byKey(const Key('preflight-save')));
    await tester.pumpAndSettle();
    expect(fake.stored, hasLength(1));
  });
}
