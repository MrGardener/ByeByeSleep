import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../alarm/alarm_platform.dart';
import '../../alarm/alarm_providers.dart';
import 'camera.dart';
import 'env_sensors.dart';
import 'heart_rate.dart';
import 'motion.dart';
import 'nfc.dart';
import 'types.dart';

/// Everything this phone can do for challenges, gathered from each source.
/// A source that fails or takes over 2 s contributes nothing (its challenges
/// get substituted).
final deviceCapabilitiesProvider = FutureProvider<Set<SensorKind>>((ref) async {
  Future<Set<SensorKind>> safe(Future<Set<SensorKind>> Function() f) async {
    try {
      return await f().timeout(const Duration(seconds: 2));
    } catch (_) {
      return {};
    }
  }

  final parts = await Future.wait([
    safe(ref.read(motionSourceProvider).available),
    safe(ref.read(envSensorProvider).available),
    for (final extra in ref.read(extraCapabilitiesProvider)) safe(extra),
  ]);
  final caps = {SensorKind.battery, for (final p in parts) ...p};
  // Hardware without its permission is as good as missing.
  try {
    final granted =
        (await ref
                .read(alarmPlatformProvider)
                .permissions()
                .timeout(const Duration(seconds: 2)))
            .granted;
    if (granted[PermissionKind.camera] == false) caps.remove(SensorKind.camera);
    if (granted[PermissionKind.activityRecognition] == false) {
      caps.remove(SensorKind.stepDetector);
    }
  } catch (_) {
    // Unknown permissions: keep what the hardware probes found.
  }
  return caps;
});

/// Further capability probes (camera, NFC) registered by their challenges.
final extraCapabilitiesProvider =
    Provider<List<Future<Set<SensorKind>> Function()>>(
      (_) => const [cameraCapability, nfcCapability, watchCapability],
    );
