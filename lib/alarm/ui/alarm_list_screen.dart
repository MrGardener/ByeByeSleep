import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../sensors/trace_recorder_screen.dart';
import '../alarm.dart';
import '../alarm_providers.dart';
import '../estimate.dart';
import '../series.dart';
import '../guard.dart';
import 'preflight_banner.dart';
import 'repeat_summary.dart';

class AlarmListScreen extends ConsumerStatefulWidget {
  const AlarmListScreen({super.key});

  @override
  ConsumerState<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends ConsumerState<AlarmListScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may come back from a system settings page, and the native
    // engine may have changed alarms meanwhile (one-shots disable after ringing).
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionStatusProvider);
      ref.invalidate(alarmListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmListProvider);
    return Scaffold(
      appBar: AppBar(
        // Long-press: developer sensor trace recorder.
        title: GestureDetector(
          onLongPress: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TraceRecorderScreen(),
            ),
          ),
          child: const Text('ByeByeSleep'),
        ),
        actions: [
          IconButton(
            key: const Key('open-quest'),
            tooltip: 'Sensor Quest',
            icon: const Icon(Icons.sports_esports),
            onPressed: () => Navigator.of(context).pushNamed(questRoute),
          ),
          IconButton(
            key: const Key('open-practice'),
            tooltip: 'Practice',
            icon: const Icon(Icons.fitness_center),
            onPressed: () => Navigator.of(context).pushNamed(practiceRoute),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-alarm'),
        onPressed: () => Navigator.of(context).pushNamed(editRoute),
        child: const Icon(Icons.add_alarm),
      ),
      body: Column(
        children: [
          const PreflightBanner(),
          Expanded(
            child: alarms.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load alarms: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No alarms yet'))
                  : ListView(
                      children: [
                        for (final a in list)
                          if (!_hasParentIn(a, list)) ...[
                            _AlarmTile(alarm: a),
                            for (final c in list.where(
                              (c) => c.parentId == a.id,
                            ))
                              _SeriesChildTile(alarm: c, main: a),
                          ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A series alarm is listed under its main alarm, not on its own.
bool _hasParentIn(Alarm a, List<Alarm> list) =>
    a.parentId != null && list.any((m) => m.id == a.parentId);

String seriesSummary(SeriesConfig s) =>
    'Series of ${s.count} · every ${s.everyMinutes} min'
    '${s.direction == SeriesDirection.before ? ' · this is the last' : ''}';

/// One alarm of a series: follows its main alarm, which is edited instead.
class _SeriesChildTile extends StatelessWidget {
  const _SeriesChildTile({required this.alarm, required this.main});

  final Alarm alarm;
  final Alarm main;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      key: Key('series-child-${alarm.id}'),
      contentPadding: const EdgeInsets.only(left: 40, right: 16),
      dense: true,
      leading: Icon(Icons.subdirectory_arrow_right, color: muted),
      title: Text(
        alarm.timeLabel,
        key: const Key('alarm-time'),
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: alarm.enabled ? null : muted),
      ),
      subtitle: Text('Part of the ${main.timeLabel} series'),
      onTap: () => Navigator.of(context).pushNamed(editRoute, arguments: main),
    );
  }
}

class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm});

  final Alarm alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(alarmListProvider.notifier);
    final subtitle = [
      if (alarm.label.isNotEmpty) alarm.label,
      repeatSummary(alarm.repeatDays),
      estimateLabel(alarm.stages, alarm.pauseSeconds),
      if (alarm.series case final s?) seriesSummary(s),
      if (alarm.reminder case final r? when !r.isEmpty)
        'Reminder: ${r.caption.isEmpty ? 'photo' : r.caption}',
    ];
    return Dismissible(
      key: Key('alarm-tile-${alarm.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmWeakening(
        ref,
        alarm,
        'Confirm deleting an alarm that rings soon',
      ),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        notifier.remove(alarm.id).catchError((Object _) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not delete the alarm.')),
          );
        });
      },
      child: ListTile(
        title: Text(
          alarm.timeLabel,
          key: const Key('alarm-time'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final s in subtitle) Text(s)],
        ),
        trailing: Switch(
          key: Key('alarm-switch-${alarm.id}'),
          value: alarm.enabled,
          onChanged: (v) async {
            if (!v &&
                !await confirmWeakening(
                  ref,
                  alarm,
                  'Confirm turning off an alarm that rings soon',
                )) {
              return;
            }
            await notifier.setEnabled(alarm.id, v);
          },
        ),
        onTap: () =>
            Navigator.of(context).pushNamed(editRoute, arguments: alarm),
      ),
    );
  }
}
