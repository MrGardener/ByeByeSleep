import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/env_sensors.dart';
import 'world_kit.dart';

/// The plant grows while the light is bright and wilts at half speed in the dark.
class SolarGarden {
  static const brightLux = 150.0;
  static const goal = Duration(seconds: 10);

  Duration grown = Duration.zero;
  Duration? _last;

  bool get passed => grown >= goal;
  double get progress => grown.inMicroseconds / goal.inMicroseconds;

  /// The app went to the background: the time away does not count.
  void pause() => _last = null;

  void update(double lux, Duration now) {
    final dt = now - (_last ?? now);
    _last = now;
    if (passed) return;
    if (lux >= brightLux) {
      grown += dt;
    } else {
      final wilted = grown - dt ~/ 2;
      grown = wilted.isNegative ? Duration.zero : wilted;
    }
  }
}

/// Solar Garden: light grows the plant (the sensor only reports changes, so
/// a timer keeps feeding the last reading).
class SolarGardenWorld extends ConsumerStatefulWidget {
  const SolarGardenWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  ConsumerState<SolarGardenWorld> createState() => _SolarGardenState();
}

class _SolarGardenState extends ConsumerState<SolarGardenWorld>
    with WidgetsBindingObserver {
  bool _away = false;

  // The light sensor only reports changes; without this, the last bright
  // reading kept the plant growing while the phone was locked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _away = state != AppLifecycleState.resumed;
    if (_away) _garden.pause();
  }

  final _garden = SolarGarden();
  late final Watchdog _watchdog;
  StreamSubscription<double>? _sub;
  Timer? _timer;
  double? _lux;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchdog = Watchdog(() => widget.args.onUnavailable?.call());
    _sub = ref.read(envSensorProvider).lux.listen((lux) {
      _watchdog.heard();
      _lux = lux;
      _feed();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) => _feed());
  }

  void _feed() {
    final lux = _lux;
    if (lux == null || !mounted || _away) return;
    _garden.update(lux, ref.read(gameClockProvider)());
    setState(() {});
    if (_garden.passed && !_reported) {
      _reported = true;
      widget.args.onPassed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog.cancel();
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lux = _lux;
    final bright = lux != null && lux >= SolarGarden.brightLux;
    return WorldPanel(
      icon: Icon(
        _garden.passed ? Icons.local_florist : Icons.eco,
        size: 40 + 100 * _garden.progress,
        color: bright ? Colors.lightGreen : Colors.brown,
      ),
      message: _garden.passed
          ? 'In full bloom!'
          : bright
          ? 'Growing…'
          : 'Too dark: find bright light.',
      detail: lux == null ? null : '${lux.round()} lux',
      progress: _garden.progress,
    );
  }
}
