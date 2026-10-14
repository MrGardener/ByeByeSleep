import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/guard.dart';
import 'world_clock.dart';

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
  var _offsets = <String, Duration>{};
  List<String> _offsetsFor = const [];
  int? _offsetsMinute;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  /// Offsets change only with summer time: refresh when the cities change
  /// and once a minute.
  void _refreshOffsets(List<String> zones, DateTime now) {
    final minute = now.millisecondsSinceEpoch ~/ 60000;
    if (identical(zones, _offsetsFor) && minute == _offsetsMinute) return;
    _offsetsFor = zones;
    _offsetsMinute = minute;
    ref.read(zoneOffsetsProvider).offsets(zones, now).then((o) {
      if (mounted) setState(() => _offsets = o);
    }, onError: (Object _) {});
  }

  Future<void> _addCity() async {
    final zone = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CityPicker(),
    );
    if (zone != null) await ref.read(worldClocksProvider.notifier).add(zone);
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
    final zones = ref.watch(worldClocksProvider).value ?? const <String>[];
    _refreshOffsets(zones, now);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      children: [
        Column(
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
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Text('World clock', style: text.titleLarge)),
            FilledButton.tonalIcon(
              key: const Key('world-add'),
              onPressed: _addCity,
              icon: const Icon(Icons.add),
              label: const Text('Add city'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (zones.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Add cities to see their time at a glance.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final zone in zones)
          if (cityForZone(zone) case final city?)
            Dismissible(
              key: Key('world-$zone'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) =>
                  ref.read(worldClocksProvider.notifier).remove(zone),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: Icon(Icons.delete_outline, color: scheme.error),
              ),
              child: Card(
                child: ListTile(
                  title: Text(city.name, style: text.titleMedium),
                  subtitle: Text(
                    _offsets[zone] == null
                        ? city.country
                        : '${cityTime(now, _offsets[zone]!, now.timeZoneOffset).dayLabel}'
                              ' · ${cityTime(now, _offsets[zone]!, now.timeZoneOffset).difference}',
                  ),
                  trailing: Text(
                    _offsets[zone] == null
                        ? '--:--'
                        : cityTime(
                            now,
                            _offsets[zone]!,
                            now.timeZoneOffset,
                          ).time,
                    style: text.headlineMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker();

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final cities = searchCities(_query);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                key: const Key('world-search'),
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search a city or country',
                ),
                onChanged: (q) => setState(() => _query = q),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in cities)
                    ListTile(
                      key: Key('city-${c.zone}'),
                      title: Text(c.name),
                      subtitle: Text(c.country),
                      onTap: () => Navigator.of(context).pop(c.zone),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
