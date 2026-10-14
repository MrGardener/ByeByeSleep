import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/guard.dart';
import 'stopwatch_state.dart';

class StopwatchNotifier extends Notifier<StopwatchState> {
  DateTime _now() => ref.read(nowProvider)();

  @override
  StopwatchState build() => const StopwatchState();

  void startOrPause() =>
      state = state.running ? state.pause(_now()) : state.start(_now());
  void lap() => state = state.lap(_now());
  void reset() => state = state.reset();
}

/// Kept while switching tabs.
final stopwatchProvider = NotifierProvider<StopwatchNotifier, StopwatchState>(
  StopwatchNotifier.new,
);

class StopwatchScreen extends ConsumerStatefulWidget {
  const StopwatchScreen({super.key});

  @override
  ConsumerState<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends ConsumerState<StopwatchScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (ref.read(stopwatchProvider).running) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = ref.watch(stopwatchProvider);
    final notifier = ref.read(stopwatchProvider.notifier);
    final now = ref.read(nowProvider)();
    final text = Theme.of(context).textTheme;
    final started = sw.running || sw.elapsed(now) > Duration.zero;
    return Column(
      children: [
        const SizedBox(height: 48),
        Text(
          formatStopwatch(sw.elapsed(now)),
          key: const Key('sw-time'),
          style: text.displayLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.tonal(
              key: Key(sw.running ? 'sw-lap' : 'sw-reset'),
              onPressed: !started
                  ? null
                  : sw.running
                  ? notifier.lap
                  : notifier.reset,
              child: Text(sw.running ? 'Lap' : 'Reset'),
            ),
            const SizedBox(width: 24),
            FilledButton(
              key: const Key('sw-start'),
              onPressed: notifier.startOrPause,
              child: Text(
                sw.running ? 'Pause' : (started ? 'Resume' : 'Start'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              for (final lap in sw.laps)
                ListTile(
                  title: Text('Lap ${lap.number}'),
                  subtitle: Text('+${formatStopwatch(lap.split)}'),
                  trailing: Text(
                    formatStopwatch(lap.total),
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
