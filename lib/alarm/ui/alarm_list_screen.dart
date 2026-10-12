import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../sensors/trace_recorder_screen.dart';
import '../alarm.dart';
import '../alarm_providers.dart';
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
                      children: [for (final a in list) _AlarmTile(alarm: a)],
                    ),
            ),
          ),
        ],
      ),
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
