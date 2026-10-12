import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/env_sensors.dart';
import 'world_kit.dart';

enum GhostPhase {
  /// Uncover the sensor so the ghost can come.
  uncover,

  /// The ghost wanders; hiding now scares it off (the wait restarts).
  wandering,

  /// The ghost is coming: hide now.
  warning,

  /// The ghost looks around; stay covered.
  looking,
}

/// Five ghost visits; keep the proximity sensor covered while it looks.
class GhostHide {
  GhostHide(this._random);

  static const visits = 5;
  static const warningTime = Duration(seconds: 1);
  static const lookTime = Duration(seconds: 2);

  final Random _random;
  GhostPhase phase = GhostPhase.uncover;
  int survived = 0;
  Duration _phaseEnds = Duration.zero;

  bool get passed => survived >= visits;
  double get progress => survived / visits;

  void update(bool near, Duration now) {
    if (passed) return;
    switch (phase) {
      case GhostPhase.uncover:
        if (!near) _wander(now);
      case GhostPhase.wandering:
        if (near) {
          phase = GhostPhase.uncover;
        } else if (now >= _phaseEnds) {
          phase = GhostPhase.warning;
          _phaseEnds = now + warningTime;
        }
      case GhostPhase.warning:
        if (now >= _phaseEnds) {
          phase = GhostPhase.looking;
          _phaseEnds = now + lookTime;
          if (!near) phase = GhostPhase.uncover; // seen at once
        }
      case GhostPhase.looking:
        if (!near) {
          phase = GhostPhase.uncover; // seen: this visit starts over
        } else if (now >= _phaseEnds) {
          survived++;
          phase = GhostPhase.uncover;
        }
    }
  }

  void _wander(Duration now) {
    phase = GhostPhase.wandering;
    _phaseEnds = now + Duration(milliseconds: 2000 + _random.nextInt(3000));
  }
}

/// Ghost Hide: cover the top of the phone (proximity sensor) when the ghost
/// comes. The phone buzzes on the warning, since a covering hand hides the
/// screen.
class GhostHideWorld extends ConsumerStatefulWidget {
  const GhostHideWorld({super.key, required this.args});

  final WorldArgs args;

  @override
  ConsumerState<GhostHideWorld> createState() => _GhostHideState();
}

class _GhostHideState extends ConsumerState<GhostHideWorld> {
  final _game = GhostHide(Random());
  late final Watchdog _watchdog;
  StreamSubscription<bool>? _sub;
  Timer? _timer;
  bool? _near;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _watchdog = Watchdog(() => widget.args.onUnavailable?.call());
    _sub = ref.read(envSensorProvider).proximityNear.listen((near) {
      _watchdog.heard();
      _near = near;
      _feed();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _feed());
  }

  void _feed() {
    final near = _near;
    if (near == null || !mounted) return;
    final before = _game.phase;
    _game.update(near, ref.read(gameClockProvider)());
    if (_game.phase == GhostPhase.warning && before != GhostPhase.warning) {
      HapticFeedback.heavyImpact();
    }
    setState(() {});
    if (_game.passed && !_reported) {
      _reported = true;
      widget.args.onPassed();
    }
  }

  @override
  void dispose() {
    _watchdog.cancel();
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (message, size) = _game.passed
        ? ('The ghost gave up!', 48.0)
        : switch (_game.phase) {
            GhostPhase.uncover => ('Uncover the top of the phone.', 48.0),
            GhostPhase.wandering => ('The ghost is wandering…', 64.0),
            GhostPhase.warning => ('It is coming: hide! Cover the top!', 110.0),
            GhostPhase.looking => ('Shh… stay hidden.', 140.0),
          };
    return WorldPanel(
      icon: Text('👻', style: TextStyle(fontSize: size)),
      message: message,
      detail: 'Survived ${_game.survived} of ${GhostHide.visits}',
      progress: _game.progress,
    );
  }
}
