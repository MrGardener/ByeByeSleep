import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic game time. Tests override it with a controllable clock.
final gameClockProvider = Provider<Duration Function()>((_) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

/// What every world widget gets.
class WorldArgs {
  const WorldArgs({required this.onPassed, this.onUnavailable});

  final VoidCallback onPassed;

  /// The sensor gave nothing; the world cannot be played right now.
  final VoidCallback? onUnavailable;
}

/// Calls [onSilent] if [heard] is not called within [wait].
class Watchdog {
  Watchdog(VoidCallback onSilent, {Duration wait = const Duration(seconds: 3)})
    : _timer = Timer(wait, onSilent);

  final Timer _timer;

  void heard() => _timer.cancel();
  void cancel() => _timer.cancel();
}

/// Icon, message and progress bar: the layout every sensor world shares.
class WorldPanel extends StatelessWidget {
  const WorldPanel({
    super.key,
    required this.icon,
    required this.message,
    required this.progress,
    this.iconSize = 96,
    this.detail,
  });

  final Widget icon;
  final String message;
  final String? detail;
  final double progress;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 160, child: Center(child: icon)),
        Text(
          message,
          key: const Key('world-message'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (detail != null) Text(detail!, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: progress.clamp(0, 1)),
      ],
    );
  }
}
