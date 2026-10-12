import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/env_sensors.dart';
import 'world_kit.dart';

/// Climb one floor: air pressure 0.30 hPa below the start, held for 2 s.
class SkyTower {
  static const drop = 0.30;
  static const calibration = Duration(seconds: 3);
  static const window = Duration(seconds: 1);
  static const hold = Duration(seconds: 2);

  final _samples = <(Duration, double)>[];
  Duration? _start;
  double? baseline;
  Duration? _belowSince;
  bool passed = false;
  double climbed = 0;

  double get progress => passed ? 1 : (climbed / drop).clamp(0, 1);

  void update(double hPa, Duration now) {
    if (passed) return;
    final start = _start ??= now;
    _samples.add((now, hPa));
    if (baseline == null) {
      if (now - start >= calibration) {
        baseline = _mean(_samples);
        _samples.clear();
      }
      return;
    }
    _samples.removeWhere((s) => now - s.$1 > window);
    climbed = baseline! - _mean(_samples);
    if (climbed >= drop - 1e-9) {
      final since = _belowSince ??= now;
      if (now - since >= hold) passed = true;
    } else {
      _belowSince = null;
    }
  }

  static double _mean(List<(Duration, double)> s) =>
      s.fold(0.0, (sum, e) => sum + e.$2) / s.length;
}

/// Sky Tower: climb real stairs; the barometer measures the height.
class SkyTowerWorld extends ConsumerStatefulWidget {
  const SkyTowerWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  ConsumerState<SkyTowerWorld> createState() => _SkyTowerState();
}

class _SkyTowerState extends ConsumerState<SkyTowerWorld> {
  final _tower = SkyTower();
  late final Watchdog _watchdog;
  StreamSubscription<double>? _sub;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _watchdog = Watchdog(() => widget.args.onUnavailable?.call());
    _sub = ref.read(envSensorProvider).pressure.listen((hPa) {
      _watchdog.heard();
      _tower.update(hPa, ref.read(gameClockProvider)());
      setState(() {});
      if (_tower.passed && !_reported) {
        _reported = true;
        widget.args.onPassed();
      }
    });
  }

  @override
  void dispose() {
    _watchdog.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Near sea level, 1 hPa ≈ 8.4 m.
    final metres = (_tower.climbed * 8.4).clamp(0, 99).toStringAsFixed(1);
    return WorldPanel(
      icon: const Icon(Icons.stairs, size: 96),
      message: _tower.passed
          ? 'You reached the top!'
          : _tower.baseline == null
          ? 'Hold still: measuring the ground floor…'
          : 'Climb one floor of stairs and wait there.',
      detail: _tower.baseline == null ? null : 'Climbed $metres m of ~2.5 m',
      progress: _tower.progress,
    );
  }
}
