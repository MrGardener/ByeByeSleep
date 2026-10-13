import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/heart_rate.dart';
import 'detector.dart';

/// Get your heart going: walk up and down the stairs until the watch shows
/// your heart rate stayed up for 15 s.
class HeartRateChallenge extends ConsumerStatefulWidget {
  const HeartRateChallenge({super.key, required this.args});

  final ChallengeArgs args;

  /// The watch app may take a while to open; then readings come every second.
  static const firstReadingTimeout = Duration(seconds: 30);

  @override
  ConsumerState<HeartRateChallenge> createState() => _HeartRateState();
}

class _HeartRateState extends ConsumerState<HeartRateChallenge> {
  late final HeartRateGoal _goal = HeartRateGoal(
    difficulty: widget.args.difficulty,
  );
  StreamSubscription<int>? _sub;
  Timer? _silence;
  int? _bpm;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _unavailable() {
    if (_done || !mounted) return;
    _done = true;
    widget.args.onUnavailable?.call();
  }

  Future<void> _start() async {
    final source = ref.read(heartRateSourceProvider);
    if (!await source.available()) return _unavailable();
    if (!mounted) return;
    _silence = Timer(HeartRateChallenge.firstReadingTimeout, _unavailable);
    final now = ref.read(heartRateClockProvider);
    _sub = source.bpm.listen((bpm) {
      _silence?.cancel();
      _goal.add(bpm, now());
      setState(() => _bpm = bpm);
      if (_goal.passed && !_done) {
        _done = true;
        widget.args.onPassed();
      }
    });
  }

  @override
  void dispose() {
    _silence?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bpm = _bpm;
    final goal = _goal.goal;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.favorite,
          size: 72,
          color: bpm != null && goal != null && bpm >= goal
              ? Colors.redAccent
              : null,
        ),
        Text(
          bpm == null ? '…' : '$bpm bpm',
          key: const Key('heart-bpm'),
          style: text.displaySmall,
        ),
        Text(
          bpm == null
              ? 'Opening ByeByeSleep on your watch…'
              : goal == null
              ? 'Measuring your resting heart rate…'
              : 'Walk up and down the stairs until it stays above $goal bpm.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: _goal.progress),
      ],
    );
  }
}
