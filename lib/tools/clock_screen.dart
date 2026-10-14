import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/guard.dart';
import 'clock_prefs.dart';
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
  void _refreshOffsets(List<City> cities, DateTime now) {
    final zones = [for (final c in cities) c.zone];
    final minute = now.millisecondsSinceEpoch ~/ 60000;
    if (_sameZones(zones) && minute == _offsetsMinute) return;
    _offsetsFor = zones;
    _offsetsMinute = minute;
    ref.read(zoneOffsetsProvider).offsets(zones, now).then((o) {
      if (mounted) setState(() => _offsets = o);
    }, onError: (Object _) {});
    _refreshWeather(cities);
  }

  bool _sameZones(List<String> zones) =>
      zones.length == _offsetsFor.length &&
      [for (var i = 0; i < zones.length; i++) zones[i] == _offsetsFor[i]]
          .every((same) => same);

  /// Weather per city (cached for 30 min by the source).
  var _weather = <String, Weather>{};

  void _refreshWeather(List<City> cities) {
    final source = ref.read(weatherSourceProvider);
    for (final c in cities) {
      final lat = c.latitude, lon = c.longitude;
      if (lat == null || lon == null) continue;
      source.current(lat, lon).then((w) {
        if (w != null && mounted) {
          setState(() => _weather = {..._weather, c.id: w});
        }
      }, onError: (Object _) {});
    }
  }

  Future<void> _addCity() async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CityPicker(),
    );
    if (city != null) await ref.read(worldClocksProvider.notifier).add(city);
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
    final cities = ref.watch(worldClocksProvider).value ?? const <City>[];
    final fahrenheit = ref.watch(fahrenheitProvider);
    final prefs = ref.watch(clockPrefsProvider).value ?? const ClockPrefs();
    final use24 = uses24(
      prefs.hours,
      systemUses24: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final home = prefs.home;
    _refreshOffsets([...cities, ?home], now);
    final homeOffset = home == null ? null : _offsets[home.zone];
    final away =
        prefs.homeClockWhenAway &&
        homeOffset != null &&
        homeOffset != now.timeZoneOffset;
    final hm = formatHm(now.hour, now.minute, use24: use24);
    final (digits, ampm) = hm.contains(' ')
        ? (hm.split(' ').first, hm.split(' ').last)
        : (hm, '');
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      children: [
        Column(
          children: [
            if (prefs.face == ClockFace.analog)
              SizedBox.square(
                key: const Key('clock-analog'),
                dimension: 240,
                child: CustomPaint(
                  painter: AnalogClockPainter(
                    now,
                    seconds: prefs.showSeconds,
                    face: scheme.surfaceContainerHigh,
                    ticks: scheme.onSurfaceVariant,
                    hands: scheme.onSurface,
                    accent: scheme.primary,
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    digits,
                    key: const Key('clock-time'),
                    style: text.displayLarge?.copyWith(
                      fontSize: 88,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (prefs.showSeconds)
                    Text(
                      ':${_two(now.second)}',
                      style: text.headlineMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  if (ampm.isNotEmpty)
                    Text(
                      ' $ampm',
                      style: text.headlineSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
              style: text.titleMedium,
            ),
            if (away)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Card(
                  key: const Key('clock-home'),
                  child: ListTile(
                    leading: Icon(Icons.home_outlined, color: scheme.primary),
                    title: Text('Home · ${home!.name}'),
                    subtitle: Text(
                      cityTime(now, homeOffset, now.timeZoneOffset).dayLabel,
                    ),
                    trailing: Text(() {
                      final t = now.toUtc().add(homeOffset);
                      return formatHm(t.hour, t.minute, use24: use24);
                    }(), style: text.headlineSmall),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Chip(
              key: const Key('clock-next-alarm'),
              avatar: Icon(next == null ? Icons.alarm_off : Icons.alarm),
              label: Text(
                next == null
                    ? 'No alarm set'
                    : 'Next alarm ${formatHm(next.$2.hour, next.$2.minute, use24: use24)}'
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
        if (cities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Add cities to see their time at a glance.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final city in cities)
          Dismissible(
            key: Key('world-${city.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) =>
                ref.read(worldClocksProvider.notifier).remove(city),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: Icon(Icons.delete_outline, color: scheme.error),
            ),
            child: Card(
              child: ListTile(
                title: Text(city.name, style: text.titleMedium),
                subtitle: Text(
                  [
                    if (_offsets[city.zone] case final o?) ...[
                      cityTime(now, o, now.timeZoneOffset).dayLabel,
                      cityTime(now, o, now.timeZoneOffset).difference,
                    ] else
                      city.place,
                    if (_weather[city.id] case final w?)
                      '${w.temperatureText(fahrenheit: fahrenheit)} ${w.description}',
                  ].join(' · '),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_weather[city.id] case final w?)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(weatherIcon(w), color: scheme.tertiary),
                      ),
                    Text(
                      _offsets[city.zone] == null
                          ? '--:--'
                          : cityTime(
                              now,
                              _offsets[city.zone]!,
                              now.timeZoneOffset,
                            ).time,
                      style: text.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A classic clock face with hour ticks and hands.
class AnalogClockPainter extends CustomPainter {
  AnalogClockPainter(
    this.time, {
    required this.seconds,
    required this.face,
    required this.ticks,
    required this.hands,
    required this.accent,
  });

  final DateTime time;
  final bool seconds;
  final Color face, ticks, hands, accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = face);
    final tick = Paint()
      ..color = ticks
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * pi / 30;
      final major = i % 5 == 0;
      tick.strokeWidth = major ? 4 : 1.5;
      final d = Offset(sin(a), -cos(a));
      canvas.drawLine(
        c + d * (r * (major ? 0.82 : 0.88)),
        c + d * (r * 0.93),
        tick,
      );
    }
    void hand(double turns, double length, double width, Color color) {
      final a = turns * 2 * pi;
      canvas.drawLine(
        c,
        c + Offset(sin(a), -cos(a)) * (r * length),
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    final s = time.second + time.millisecond / 1000;
    final m = time.minute + s / 60;
    final h = time.hour % 12 + m / 60;
    hand(h / 12, 0.5, 8, hands);
    hand(m / 60, 0.75, 5, hands);
    if (seconds) hand(s / 60, 0.85, 2, accent);
    canvas.drawCircle(c, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(AnalogClockPainter old) =>
      old.time != time || old.seconds != seconds;
}

IconData weatherIcon(Weather w) => switch (w.code) {
  0 || 1 => w.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_outlined,
  2 || 3 => Icons.cloud_outlined,
  45 || 48 => Icons.foggy,
  >= 71 && <= 77 || 85 || 86 => Icons.ac_unit,
  >= 95 => Icons.thunderstorm_outlined,
  >= 51 => Icons.water_drop_outlined,
  _ => Icons.cloud_outlined,
};

class CityPicker extends ConsumerStatefulWidget {
  const CityPicker({super.key});

  @override
  ConsumerState<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends ConsumerState<CityPicker> {
  var _query = '';
  var _online = const <City>[];
  var _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String q) {
    setState(() => _query = q);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.trim().length < 2) {
        if (mounted) setState(() => _online = const []);
        return;
      }
      setState(() => _searching = true);
      List<City> found;
      try {
        found = await searchCitiesOnline(ref.read(httpGetProvider), q);
      } catch (_) {
        found = const []; // offline: the built-in cities still work
      }
      if (mounted && q == _query) {
        setState(() {
          _online = found;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final local = searchCities(_query);
    final known = {for (final c in local) '${c.name}|${c.zone}'};
    final cities = [
      ...local,
      for (final c in _online)
        if (!known.contains('${c.name}|${c.zone}')) c,
    ];
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
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search any city in the world',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _changed,
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in cities)
                    ListTile(
                      key: Key('city-${c.id}'),
                      title: Text(c.name),
                      subtitle: Text(c.place),
                      onTap: () => Navigator.of(context).pop(c),
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
