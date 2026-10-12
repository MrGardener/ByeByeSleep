import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/challenges/core/capabilities.dart';
import 'package:byebyesleep/challenges/core/env_sensors.dart';
import 'package:byebyesleep/challenges/core/motion.dart';
import 'package:byebyesleep/challenges/core/types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';
import '../support/fake_env_sensors.dart';
import '../support/fake_motion_source.dart';

void main() {
  Future<Set<SensorKind>> capabilities(PermissionStatus permissions) {
    final c = ProviderContainer(
      overrides: [
        alarmPlatformProvider.overrideWithValue(
          FakeAlarmPlatform(permissionStatus: permissions),
        ),
        motionSourceProvider.overrideWithValue(FakeMotionSource()),
        envSensorProvider.overrideWithValue(FakeEnvSensors()),
        extraCapabilitiesProvider.overrideWithValue([
          () async => {SensorKind.camera},
        ]),
      ],
    );
    addTearDown(c.dispose);
    return c.read(deviceCapabilitiesProvider.future);
  }

  test('all present with permissions', () async {
    expect(
      await capabilities(PermissionStatus.unknownAllGranted),
      containsAll([
        SensorKind.camera,
        SensorKind.stepDetector,
        SensorKind.battery,
      ]),
    );
  });

  test('missing permissions drop camera and step detector', () async {
    final caps = await capabilities(
      const PermissionStatus({
        PermissionKind.camera: false,
        PermissionKind.activityRecognition: false,
      }),
    );
    expect(caps, isNot(contains(SensorKind.camera)));
    expect(caps, isNot(contains(SensorKind.stepDetector)));
    expect(caps, contains(SensorKind.light));
  });
}
