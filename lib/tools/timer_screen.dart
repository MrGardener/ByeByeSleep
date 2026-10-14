import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/guard.dart';
import 'timer_bell.dart';
import 'timer_state.dart';

const _presetMinutes = [1, 3, 5, 10, 15, 30];

/// Pick a length and start as many timers as you like; each rings on its own.
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
      final timers = ref.read(timersProvider).value?.timers ?? const [];
      if (timers.any((t) => t.state.running)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _custom(Duration current) async {
    var picked = current;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 216,
            child: CupertinoTimerPicker(
              initialTimerDuration: current,
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
      await ref.read(timersProvider.notifier).choose(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(timersProvider).value;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final notifier = ref.read(timersProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final now = ref.read(nowProvider)();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('New timer', style: text.titleMedium),
                Text(
                  formatTimer(s.composer),
                  key: const Key('timer-composer'),
                  style: text.displayMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
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
                          color: s.composer == Duration(minutes: m)
                              ? scheme.onPrimary
                              : scheme.onSurface,
                        ),
                        selected: s.composer == Duration(minutes: m),
                        onSelected: (_) =>
                            notifier.choose(Duration(minutes: m)),
                      ),
                    ActionChip(
                      key: const Key('timer-custom'),
                      avatar: const Icon(Icons.edit, size: 18),
                      label: const Text('Custom'),
                      onPressed: () => _custom(s.composer),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('timer-add'),
                  onPressed: notifier.add,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('Start ${formatTimer(s.composer)}'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final t in s.timers.reversed)
          _TimerCard(entry: t, now: now, notifier: notifier),
      ],
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.entry,
    required this.now,
    required this.notifier,
  });

  final TimerEntry entry;
  final DateTime now;
  final TimersNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final t = entry.state;
    final id = entry.id;
    final left = t.remaining(now);
    final done = t.isDone(now);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = t.total.inMilliseconds == 0
        ? 0.0
        : (left.inMilliseconds / t.total.inMilliseconds).clamp(0.0, 1.0);
    return Card(
      key: Key('timer-$id'),
      color: done ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 56,
              child: CircularProgressIndicator(
                value: done ? 1 : fraction,
                strokeWidth: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? "Time's up" : formatTimer(left),
                    style: text.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${formatTimer(t.total)} timer'
                    '${!done && !t.running ? ' · paused' : ''}',
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (done)
              FilledButton(
                key: Key('timer-$id-stop'),
                onPressed: () => notifier.remove(id),
                child: const Text('Stop'),
              )
            else ...[
              IconButton(
                key: Key('timer-$id-plus'),
                tooltip: '+1 min',
                onPressed: () => notifier.addMinute(id),
                icon: const Icon(Icons.more_time),
              ),
              IconButton.filled(
                key: Key('timer-$id-toggle'),
                tooltip: t.running ? 'Pause' : 'Resume',
                onPressed: () => notifier.toggle(id),
                icon: Icon(
                  t.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              IconButton(
                key: Key('timer-$id-delete'),
                tooltip: 'Delete',
                onPressed: () => notifier.remove(id),
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
