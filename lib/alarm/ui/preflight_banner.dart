import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm_platform.dart';
import '../alarm_providers.dart';

const _labels = {
  PermissionKind.exactAlarm: 'Exact alarms',
  PermissionKind.fullScreenIntent: 'Full-screen alarm',
  PermissionKind.notifications: 'Notifications',
  PermissionKind.ignoreBatteryOptimizations: 'Battery optimisation off',
  PermissionKind.activityRecognition: 'Physical activity (step challenges)',
  PermissionKind.camera: 'Camera (photo and barcode challenges)',
};

/// Warns when alarms cannot ring: no alarm engine on this platform, or
/// permissions the alarm engine is missing.
class PreflightBanner extends ConsumerWidget {
  const PreflightBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(alarmSupportedProvider).value == false) {
      return Card(
        key: const Key('unsupported-banner'),
        color: Theme.of(context).colorScheme.errorContainer,
        margin: const EdgeInsets.all(12),
        child: const ListTile(
          title: Text("Alarms can't ring on this phone yet"),
          subtitle: Text('iPhone support arrives in a later update.'),
        ),
      );
    }
    final status = ref.watch(permissionStatusProvider).value;
    // Challenge-specific permissions are asked for during setup and checked
    // by the pre-flight check; the banner covers what every alarm needs.
    if (status == null || status.coreMissing.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('preflight-banner'),
      color: scheme.errorContainer,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Alarms may not ring',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final kind in status.coreMissing)
              ListTile(
                dense: true,
                title: Text(_labels[kind]!),
                trailing: TextButton(
                  key: Key('fix-${kind.name}'),
                  onPressed: () =>
                      ref.read(alarmPlatformProvider).openSettings(kind),
                  child: const Text('Fix'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
