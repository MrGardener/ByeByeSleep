import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/settings_screen.dart';
import '../../app/theme.dart';
import '../../app/ui_kit.dart';
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wb_twilight_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              const Text('ByeByeSleep'),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        key: const Key('add-alarm'),
        tooltip: 'Add alarm',
        onPressed: () => Navigator.of(context).pushNamed(editRoute),
        child: const Icon(Icons.add_alarm_rounded, size: 36),
      ),
      body: Column(
        children: [
          const PreflightBanner(),
          Expanded(
            child: alarms.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load alarms: $e')),
              data: (list) => list.isEmpty
                  ? const _EmptyAlarms()
                  : ListView(
                      // Room for the add button under the last alarm.
                      padding: const EdgeInsets.only(top: 4, bottom: 120),
                      children: [
                        _NextAlarmCard(alarms: list),
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

/// "5 h 20 min", "45 min", "under a minute".
String untilLabel(Duration d) {
  final minutes = (d.inSeconds / 60).ceil();
  if (minutes < 1) return 'under a minute';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  if (m == 0) return '$h h';
  return '$h h $m min';
}

/// The hero at the top of the list: how long until the next alarm.
class _NextAlarmCard extends ConsumerStatefulWidget {
  const _NextAlarmCard({required this.alarms});

  final List<Alarm> alarms;

  @override
  ConsumerState<_NextAlarmCard> createState() => _NextAlarmCardState();
}

class _NextAlarmCardState extends ConsumerState<_NextAlarmCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keeps the countdown current while the list is open.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    Alarm? next;
    DateTime? at;
    for (final a in widget.alarms) {
      final t = nextRing(a, now);
      if (t != null && (at == null || t.isBefore(at))) {
        next = a;
        at = t;
      }
    }
    final text = Theme.of(context).textTheme;
    if (next == null || at == null) {
      return HeroCard(
        key: const Key('next-alarm-card'),
        child: Row(
          children: [
            const Icon(Icons.bedtime_outlined, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'All alarms are off. Sleep in!',
                style: text.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    final day = at.day == now.day && at.difference(now).inHours < 24
        ? 'Today'
        : at.difference(DateTime(now.year, now.month, now.day)).inDays == 1
        ? 'Tomorrow'
        : dayName(at.weekday);
    return HeroCard(
      key: const Key('next-alarm-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.alarm_on_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'NEXT ALARM',
                style: text.labelMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'in ${untilLabel(at.difference(now))}',
            key: const Key('next-alarm-in'),
            style: text.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              '$day ${next.timeLabel}',
              if (next.label.isNotEmpty) next.label,
            ].join(' · '),
            style: text.titleMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// No alarms yet: a calm sunrise and one clear next step.
class _EmptyAlarms extends StatelessWidget {
  const _EmptyAlarms();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SunriseColors.of(context).hero,
              ),
              child: const Icon(
                Icons.wb_twilight_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No alarms yet',
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set one and actually get up: a short challenge stands '
              'between you and the Stop button.',
              style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

List<Alarm> _seriesOf(WidgetRef ref, Alarm main) => [
  for (final a in ref.read(alarmListProvider).value ?? const <Alarm>[])
    if (a.parentId == main.id) a,
];

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
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 16, 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: Key('series-child-${alarm.id}'),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Icon(Icons.subdirectory_arrow_right_rounded, color: muted),
          title: Text(
            alarm.timeLabel,
            key: const Key('alarm-time'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: alarm.enabled ? null : muted,
            ),
          ),
          subtitle: Text('Part of the ${main.timeLabel} series'),
          onTap: () =>
              Navigator.of(context).pushNamed(editRoute, arguments: main),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final on = alarm.enabled;
    final muted = scheme.onSurfaceVariant;
    final details = [
      (Icons.timer_outlined, estimateLabel(alarm.stages, alarm.pauseSeconds)),
      if (alarm.series case final s?) (Icons.repeat_rounded, seriesSummary(s)),
      if (alarm.reminder case final r? when !r.isEmpty)
        (
          Icons.photo_camera_outlined,
          'Reminder: ${r.caption.isEmpty ? 'photo' : r.caption}',
        ),
    ];
    return Dismissible(
      key: Key('alarm-tile-${alarm.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmWeakening(
        ref,
        alarm,
        'Confirm deleting an alarm that rings soon',
        series: _seriesOf(ref, alarm),
      ),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) {
        final messenger = ScaffoldMessenger.of(context);
        notifier.remove(alarm.id).catchError((Object _) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not delete the alarm.')),
          );
        });
      },
      child: Card(
        color: on ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow,
        child: InkWell(
          onTap: () =>
              Navigator.of(context).pushNamed(editRoute, arguments: alarm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (alarm.label.isNotEmpty)
                        Text(
                          alarm.label,
                          style: text.titleMedium?.copyWith(
                            color: on ? scheme.onSurface : muted,
                          ),
                        ),
                      Text(
                        alarm.timeLabel,
                        key: const Key('alarm-time'),
                        style: text.displayMedium?.copyWith(
                          fontWeight: on ? FontWeight.w500 : FontWeight.w300,
                          color: on ? scheme.onSurface : muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        repeatSummary(alarm.repeatDays),
                        style: text.labelLarge?.copyWith(
                          color: on ? scheme.primary : muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final (icon, line) in details)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(icon, size: 16, color: muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  line,
                                  style: text.bodyMedium?.copyWith(
                                    color: muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  key: Key('alarm-switch-${alarm.id}'),
                  value: alarm.enabled,
                  onChanged: (v) async {
                    if (!v &&
                        !await confirmWeakening(
                          ref,
                          alarm,
                          'Confirm turning off an alarm that rings soon',
                          series: _seriesOf(ref, alarm),
                        )) {
                      return;
                    }
                    await notifier.setEnabled(alarm.id, v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
