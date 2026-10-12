import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env_sensors.dart';
import '../core/setup_scaffold.dart';

/// Measures the room with the light on; the alarm then needs half of that.
Future<Map<String, Object?>?> setupLights(
  BuildContext context,
  Map<String, Object?> current,
) => Navigator.of(context).push<Map<String, Object?>>(
  MaterialPageRoute(builder: (_) => const _LightsSetupScreen()),
);

class _LightsSetupScreen extends ConsumerStatefulWidget {
  const _LightsSetupScreen();

  @override
  ConsumerState<_LightsSetupScreen> createState() => _LightsSetupScreenState();
}

class _LightsSetupScreenState extends ConsumerState<_LightsSetupScreen> {
  StreamSubscription<double>? _sub;
  double? _lux;

  @override
  void initState() {
    super.initState();
    _sub = ref
        .read(envSensorProvider)
        .lux
        .listen((v) => setState(() => _lux = v));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lux = _lux;
    return SetupScaffold(
      title: 'Lights on — setup',
      explanation:
          'Switch on the light you use in the morning, hold the phone where '
          'it sits at night, then tap Save.',
      onSave: lux == null ? null : () => {'lux': lux},
      child: Text(
        lux == null ? 'Measuring…' : '${lux.round()} lux',
        style: Theme.of(context).textTheme.displaySmall,
      ),
    );
  }
}
