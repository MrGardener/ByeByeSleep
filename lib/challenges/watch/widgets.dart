import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/watch.dart';
import 'detectors.dart';

/// Shared plumbing for wrist challenges: checks a watch is there, opens its
/// sensor screen, and gives up (fallback) if nothing arrives in 30 s.
abstract class _WatchChallengeState<T extends ConsumerStatefulWidget>
    extends ConsumerState<T> {
  ChallengeArgs get args;
  StreamSubscription<WatchReading>? _sub;
  Timer? _silence;
  bool _done = false;
  bool connected = false;

  void onReading(WatchReading r);

  /// Whether [r] is what this challenge needs. Only those keep it waiting:
  /// motion alone must not hold a steps challenge open for ever (steps
  /// refused on the watch, or no step sensor).
  bool uses(WatchReading r);

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _unavailable() {
    if (_done || !mounted) return;
    _done = true;
    args.onUnavailable?.call();
  }

  void pass() {
    if (_done) return;
    _done = true;
    args.onPassed();
  }

  Future<void> _start() async {
    final watch = ref.read(watchSourceProvider);
    if (!await watch.available()) return _unavailable();
    if (!mounted) return;
    _silence = Timer(const Duration(seconds: 30), _unavailable);
    _sub = watch.readings.listen((r) {
      if (!uses(r)) return;
      _silence?.cancel();
      if (!mounted) return;
      setState(() {
        connected = true;
        onReading(r);
      });
    });
  }

  @override
  void dispose() {
    _silence?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

Widget _panel(
  BuildContext context, {
  required IconData icon,
  required String big,
  required String text,
  required double progress,
}) => Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 72),
    Text(big, style: Theme.of(context).textTheme.displaySmall),
    Text(text, textAlign: TextAlign.center),
    const SizedBox(height: 12),
    LinearProgressIndicator(value: progress),
  ],
);

/// Wrist workout: swing your arm (the one wearing the watch) N times.
class WatchSwingChallenge extends ConsumerStatefulWidget {
  const WatchSwingChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<WatchSwingChallenge> createState() => _SwingState();
}

class _SwingState extends _WatchChallengeState<WatchSwingChallenge> {
  final _counter = SwingCounter();
  late final int _target = swingsFor(widget.args.difficulty);

  @override
  ChallengeArgs get args => widget.args;

  @override
  bool uses(WatchReading r) => r is MotionReading;

  @override
  void onReading(WatchReading r) {
    if (r is! MotionReading) return;
    _counter.addAll(r.magnitudes);
    if (_counter.swings >= _target) pass();
  }

  @override
  Widget build(BuildContext context) => _panel(
    context,
    icon: Icons.sports_gymnastics,
    big: '${_counter.swings.clamp(0, _target)} / $_target',
    text: connected
        ? 'Swing the arm with the watch up and down, big and brisk.'
        : 'Opening ByeByeSleep on your watch…',
    progress: (_counter.swings / _target).clamp(0, 1).toDouble(),
  );
}

/// Walk with your watch: steps counted on the wrist, so leaving the phone on
/// the nightstand does not help.
class WatchStepsChallenge extends ConsumerStatefulWidget {
  const WatchStepsChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<WatchStepsChallenge> createState() => _StepsState();
}

class _StepsState extends _WatchChallengeState<WatchStepsChallenge> {
  late final _goal = StepGoal(stepsFor(widget.args.difficulty));

  @override
  ChallengeArgs get args => widget.args;

  @override
  bool uses(WatchReading r) => r is StepsReading;

  @override
  void onReading(WatchReading r) {
    if (r is! StepsReading) return;
    _goal.update(r.steps);
    if (_goal.passed) pass();
  }

  @override
  Widget build(BuildContext context) => _panel(
    context,
    icon: Icons.directions_walk,
    big: '${_goal.walked} of ${_goal.target}',
    text: connected
        ? 'Walk around — your watch counts the steps.'
        : 'Opening ByeByeSleep on your watch…',
    progress: _goal.progress,
  );
}
