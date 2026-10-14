import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/guard.dart';

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday', //
];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// The next ring of any switched-on alarm after [now], with its alarm.
(Alarm, DateTime)? nextAlarm(List<Alarm> alarms, DateTime now) {
  (Alarm, DateTime)? best;
  for (final a in alarms) {
    final at = nextRing(a, now);
    if (at == null) continue;
    if (best == null || at.isBefore(best.$2)) best = (a, at);
  }
  return best;
}

String untilText(Duration d) {
  final mins = d.inMinutes;
  if (mins < 1) return 'in less than a minute';
  if (mins < 60) return 'in $mins min';
  final h = mins ~/ 60, m = mins % 60;
  return m == 0 ? 'in $h h' : 'in $h h $m min';
}

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(nowProvider)();
    final alarms = ref.watch(alarmListProvider).value ?? const <Alarm>[];
    final next = nextAlarm(alarms, now);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_two(now.hour)}:${_two(now.minute)}',
                key: const Key('clock-time'),
                style: text.displayLarge?.copyWith(
                  fontSize: 88,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                ':${_two(now.second)}',
                style: text.headlineMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Text(
            '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
            style: text.titleMedium,
          ),
          const SizedBox(height: 32),
          Chip(
            key: const Key('clock-next-alarm'),
            avatar: Icon(next == null ? Icons.alarm_off : Icons.alarm),
            label: Text(
              next == null
                  ? 'No alarm set'
                  : 'Next alarm ${_two(next.$2.hour)}:${_two(next.$2.minute)}'
                        ' · ${untilText(next.$2.difference(now))}',
            ),
          ),
        ],
      ),
    );
  }
}
