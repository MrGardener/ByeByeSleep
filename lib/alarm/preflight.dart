import '../challenges/core/challenge_id.dart';
import '../challenges/registry.dart';
import 'alarm.dart';
import 'alarm_platform.dart';

const _permissionNames = {
  PermissionKind.exactAlarm: 'Exact alarms',
  PermissionKind.fullScreenIntent: 'Full-screen alarm',
  PermissionKind.notifications: 'Notifications',
  PermissionKind.ignoreBatteryOptimizations: 'Battery optimisation',
};

/// Why [alarm] might not work as intended, one sentence each (spec §6.1).
List<String> preflightProblems(Alarm alarm, PermissionStatus permissions) {
  final problems = [
    for (final kind in permissions.coreMissing)
      '${_permissionNames[kind]} permission is off.',
  ];
  for (var i = 0; i < alarm.stages.length; i++) {
    final stage = alarm.stages[i];
    final definition = definitionFor(stage.challenge);
    if (!definition.isSetUp(stage.params)) {
      problems.add('Stage ${i + 1} (${definition.title}) needs setup.');
    }
    final needsCamera =
        stage.challenge == ChallengeId.photoMatch ||
        stage.challenge == ChallengeId.barcode;
    if (needsCamera && permissions.granted[PermissionKind.camera] == false) {
      problems.add('Camera permission is off (needed by stage ${i + 1}).');
    }
    if (stage.challenge == ChallengeId.walkSteps &&
        permissions.granted[PermissionKind.activityRecognition] == false) {
      problems.add(
        'Physical activity permission is off (needed by stage ${i + 1}).',
      );
    }
  }
  return problems;
}
