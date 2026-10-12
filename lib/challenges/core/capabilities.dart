import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'camera.dart';
import 'env_sensors.dart';
import 'motion.dart';
import 'types.dart';

/// Everything this phone can do for challenges, gathered from each source.
/// A source that fails contributes nothing (its challenges get substituted).
final deviceCapabilitiesProvider = FutureProvider<Set<SensorKind>>((ref) async {
  Future<Set<SensorKind>> safe(Future<Set<SensorKind>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return {};
    }
  }

  final parts = await Future.wait([
    safe(ref.read(motionSourceProvider).available),
    safe(ref.read(envSensorProvider).available),
    for (final extra in ref.read(extraCapabilitiesProvider)) safe(extra),
  ]);
  return {SensorKind.battery, for (final p in parts) ...p};
});

/// Further capability probes (camera, NFC) registered by their challenges.
final extraCapabilitiesProvider =
    Provider<List<Future<Set<SensorKind>> Function()>>(
      (_) => const [cameraCapability],
    );
