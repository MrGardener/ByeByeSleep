import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'clock_prefs.dart';
import 'clock_screen.dart';
import 'world_clock.dart';

/// Settings → Clock: face, 12/24 h, seconds and the home time zone.
class ClockSettingsSection extends ConsumerWidget {
  const ClockSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(clockPrefsProvider).value ?? const ClockPrefs();
    final notifier = ref.read(clockPrefsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(s, style: text.titleSmall),
    );
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label('Clock style'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ClockFace>(
              segments: const [
                ButtonSegment(
                  value: ClockFace.digital,
                  label: Text('Digital', key: Key('clock-face-digital')),
                  icon: Icon(Icons.pin_outlined),
                ),
                ButtonSegment(
                  value: ClockFace.analog,
                  label: Text('Analog', key: Key('clock-face-analog')),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {p.face},
              onSelectionChanged: (s) =>
                  notifier.change((p) => p.copyWith(face: s.first)),
            ),
          ),
          label('Time format'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<TimeFormat>(
              segments: const [
                ButtonSegment(
                  value: TimeFormat.system,
                  label: Text('Phone', key: Key('clock-hours-system')),
                ),
                ButtonSegment(
                  value: TimeFormat.h24,
                  label: Text('24 h', key: Key('clock-hours-h24')),
                ),
                ButtonSegment(
                  value: TimeFormat.h12,
                  label: Text('12 h', key: Key('clock-hours-h12')),
                ),
              ],
              selected: {p.hours},
              onSelectionChanged: (s) =>
                  notifier.change((p) => p.copyWith(hours: s.first)),
            ),
          ),
          SwitchListTile(
            key: const Key('clock-seconds'),
            title: const Text('Show seconds'),
            value: p.showSeconds,
            onChanged: (v) =>
                notifier.change((p) => p.copyWith(showSeconds: v)),
          ),
          ListTile(
            key: const Key('clock-home'),
            leading: Icon(Icons.home_outlined, color: scheme.primary),
            title: const Text('Home time zone'),
            subtitle: Text(
              p.home == null
                  ? "The phone's time zone"
                  : '${p.home!.name} (${p.home!.zone.replaceAll('_', ' ')})',
            ),
            trailing: p.home == null
                ? const Icon(Icons.chevron_right_rounded)
                : IconButton(
                    key: const Key('clock-home-clear'),
                    tooltip: "Use the phone's time zone",
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        notifier.change((p) => p.copyWith(home: () => null)),
                  ),
            onTap: () async {
              final city = await showModalBottomSheet<City>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const CityPicker(),
              );
              if (city != null) {
                await notifier.change((p) => p.copyWith(home: () => city));
              }
            },
          ),
          SwitchListTile(
            key: const Key('clock-home-away'),
            title: const Text('Show home time when travelling'),
            subtitle: const Text(
              'When the phone is in another time zone, the clock shows home '
              'time too.',
            ),
            value: p.homeClockWhenAway,
            onChanged: p.home == null
                ? null
                : (v) =>
                      notifier.change((p) => p.copyWith(homeClockWhenAway: v)),
          ),
        ],
      ),
    );
  }
}
