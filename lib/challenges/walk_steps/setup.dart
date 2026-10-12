import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env_sensors.dart';
import '../core/setup_scaffold.dart';
import 'detector.dart';

/// Counts the steps from bed to the user's spot.
Future<Map<String, Object?>?> setupWalk(
  BuildContext context,
  Map<String, Object?> current,
) => Navigator.of(context).push<Map<String, Object?>>(
  MaterialPageRoute(builder: (_) => const _WalkSetupScreen()),
);

class _WalkSetupScreen extends ConsumerStatefulWidget {
  const _WalkSetupScreen();

  @override
  ConsumerState<_WalkSetupScreen> createState() => _WalkSetupScreenState();
}

class _WalkSetupScreenState extends ConsumerState<_WalkSetupScreen> {
  StreamSubscription<Duration>? _sub;
  int _steps = 0;
  Duration? _last;
  String? _error;

  Future<void> _start() async {
    final sensors = ref.read(envSensorProvider);
    if (!await sensors.requestActivityPermission()) {
      setState(() => _error = 'Allow physical activity to count steps.');
      return;
    }
    await _sub?.cancel();
    setState(() {
      _steps = 0;
      _last = null;
      _error = null;
    });
    _sub = sensors.steps.listen((t) {
      final last = _last;
      if (last == null || t - last >= minStepInterval) {
        _last = t;
        setState(() => _steps++);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SetupScaffold(
      title: 'Walk — setup',
      explanation:
          'Stand at your bed, tap Start, walk normally to the place you want '
          'to reach every morning (kitchen, bathroom…), then tap Save.',
      onSave: _steps >= 5 ? () => {'steps': _steps} : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_steps steps',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          if (_error != null) Text(_error!),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('walk-start'),
            onPressed: _start,
            child: Text(_sub == null ? 'Start' : 'Restart'),
          ),
        ],
      ),
    );
  }
}
