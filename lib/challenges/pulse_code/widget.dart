import 'dart:async';

import 'package:flutter/material.dart';

import '../core/challenge.dart';
import 'code.dart';

/// Pulse code: watch the light flash short and long, then tap it back.
/// Visual (the phone already vibrates while the alarm rings).
class PulseCodeChallenge extends StatefulWidget {
  const PulseCodeChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<PulseCodeChallenge> createState() => _PulseCodeState();
}

class _PulseCodeState extends State<PulseCodeChallenge> {
  late final PulseCode _code = switch (widget.args.params['code']) {
    // Fixed codes for tests: 'S' short, 'L' long.
    final String s => PulseCode([
      for (final c in s.split('')) c == 'L' ? Pulse.long : Pulse.short,
    ]),
    _ => PulseCode.random(widget.args.random, widget.args.difficulty),
  };
  late CodeAttempt _attempt = _code.attempt();
  bool _showing = true;
  bool _lit = false;
  String? _message;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _play();
  }

  /// Plays the flash timeline once (after a short pause), then lets you type.
  void _play() {
    _timer?.cancel();
    final steps = [
      const Flash(false, Duration(milliseconds: 800)),
      ..._code.timeline(),
    ];
    var i = 0;
    void next() {
      if (!mounted) return;
      if (i == steps.length) {
        setState(() {
          _showing = false;
          _lit = false;
        });
        return;
      }
      final step = steps[i++];
      setState(() => _lit = step.on);
      _timer = Timer(step.length, next);
    }

    setState(() {
      _showing = true;
      _attempt = _code.attempt();
    });
    next();
  }

  void _tap(Pulse p) {
    _attempt.add(p);
    switch (_attempt.state) {
      case AttemptState.right:
        setState(() => _message = 'Defused!');
        if (!_done) {
          _done = true;
          widget.args.onPassed();
        }
      case AttemptState.wrong:
        setState(() => _message = 'Wrong — watch the code again.');
        _play();
      case AttemptState.going:
        setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lit ? scheme.tertiary : scheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _showing
              ? 'Watch: a short flash or a long flash, '
                    '${_code.pulses.length} in all.'
              : 'Tap the code back (${_attempt.typed.length} of '
                    '${_code.pulses.length}).',
          textAlign: TextAlign.center,
        ),
        if (_message != null) Text(_message!),
        const SizedBox(height: 16),
        if (!_showing)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonal(
                key: const Key('pulse-short'),
                onPressed: () => _tap(Pulse.short),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Short'),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.tonal(
                key: const Key('pulse-long'),
                onPressed: () => _tap(Pulse.long),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Text('Long'),
                ),
              ),
            ],
          ),
        if (!_showing)
          TextButton(onPressed: _play, child: const Text('Show it again')),
      ],
    );
  }
}
