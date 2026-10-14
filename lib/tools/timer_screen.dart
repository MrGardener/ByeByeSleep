import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/guard.dart';
import 'timer_bell.dart';
import 'timer_state.dart';

const _presetMinutes = [1, 3, 5, 10, 15, 30];

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (ref.read(timerProvider).value?.running ?? false) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _custom(TimerState t) async {
    var picked = t.total;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoTimerPicker(
              initialTimerDuration: t.total,
              onTimerDurationChanged: (d) => picked = d,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              key: const Key('timer-custom-ok'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Set'),
            ),
          ),
        ],
      ),
    );
    if (ok == true && picked > Duration.zero) {
      await ref.read(timerProvider.notifier).choose(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(timerProvider).value;
    if (t == null) return const Center(child: CircularProgressIndicator());
    final notifier = ref.read(timerProvider.notifier);
    final now = ref.read(nowProvider)();
    final left = t.remaining(now);
    final done = t.isDone(now);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = t.total.inMilliseconds == 0
        ? 0.0
        : (left.inMilliseconds / t.total.inMilliseconds).clamp(0.0, 1.0);
    final idle = !t.running && t.pausedLeft == null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: SizedBox.square(
            dimension: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: done ? 1 : fraction,
                  strokeWidth: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                Center(
                  child: Text(
                    done ? "Time's up" : formatTimer(left),
                    style: (done ? text.headlineMedium : text.displayMedium)
                        ?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (done)
          Center(
            child: FilledButton.icon(
              key: const Key('timer-stop'),
              onPressed: notifier.reset,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.tonal(
                key: const Key('timer-reset'),
                onPressed: idle ? null : notifier.reset,
                child: const Text('Reset'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                key: const Key('timer-start'),
                onPressed: notifier.startOrPause,
                child: Text(t.running ? 'Pause' : (idle ? 'Start' : 'Resume')),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                key: const Key('timer-plus'),
                onPressed: idle ? null : notifier.addMinute,
                child: const Text('+1 min'),
              ),
            ],
          ),
        const SizedBox(height: 32),
        if (idle)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presetMinutes)
                ChoiceChip(
                  key: Key('timer-preset-$m'),
                  label: Text('$m min'),
                  labelStyle: TextStyle(
                    color: t.total == Duration(minutes: m)
                        ? scheme.onPrimary
                        : scheme.onSurface,
                  ),
                  selected: t.total == Duration(minutes: m),
                  onSelected: (_) => notifier.choose(Duration(minutes: m)),
                ),
              ActionChip(
                key: const Key('timer-custom'),
                avatar: const Icon(Icons.edit, size: 18),
                label: const Text('Custom'),
                onPressed: () => _custom(t),
              ),
            ],
          ),
      ],
    );
  }
}
