import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tools/bedtime.dart';
import '../tools/clock_settings_section.dart';
import '../watch_setup/watch_settings.dart';
import '../watch_setup/watch_setup_screen.dart';
import 'ui_kit.dart';

/// App settings: clock, smartwatch and the bedtime reminder.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _names = {
    'heartRate': 'heart rate',
    'watchMotion': 'wrist movement',
    'watchSteps': 'steps',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watch =
        ref.watch(watchSettingsProvider).value ?? const WatchSettings();
    final status = switch (watch.choice) {
      WatchChoice.unknown => 'Not set up',
      WatchChoice.none => 'No watch (watch challenges hidden)',
      WatchChoice.verified =>
        'Ready: ${watch.sensors.map((s) => _names[s.name]).join(', ')}',
    };
    final bedtime = ref.watch(bedtimeProvider).value;
    final scheme = Theme.of(context).colorScheme;
    String two(int n) => n.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              'CLOCK',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const ClockSettingsSection(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'DEVICES',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('settings-watch'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: IconBadge(
                Icons.watch_outlined,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: const Text('Smartwatch'),
              subtitle: Text(status),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WatchSetupScreen(),
                ),
              ),
            ),
          ),
          if (bedtime != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'SLEEP',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('bedtime-switch'),
                    secondary: IconBadge(
                      Icons.bedtime_outlined,
                      color: scheme.tertiary,
                    ),
                    title: const Text('Bedtime reminder'),
                    subtitle: Text(
                      !bedtime.enabled
                          ? 'Off'
                          : bedtime.nextAt == null
                          ? 'No alarm ahead'
                          : 'Next reminder ${two(bedtime.nextAt!.hour)}:'
                                '${two(bedtime.nextAt!.minute)}, for '
                                '${sleepLabel(bedtime.sleepMinutes)} of sleep',
                    ),
                    value: bedtime.enabled,
                    onChanged: (on) => ref
                        .read(bedtimeProvider.notifier)
                        .change((b) => b.copyWith(enabled: on)),
                  ),
                  ListTile(
                    enabled: bedtime.enabled,
                    title: const Text('Sleep goal'),
                    subtitle: const Text(
                      'The reminder comes this long before your first alarm.',
                    ),
                    trailing: DropdownButton<int>(
                      key: const Key('bedtime-goal'),
                      value: bedtime.sleepMinutes,
                      onChanged: !bedtime.enabled
                          ? null
                          : (m) => ref
                                .read(bedtimeProvider.notifier)
                                .change((b) => b.copyWith(sleepMinutes: m)),
                      items: [
                        for (final m in {...sleepGoals, bedtime.sleepMinutes})
                          DropdownMenuItem(
                            value: m,
                            child: Text(sleepLabel(m)),
                          ),
                      ],
                    ),
                  ),
                  ListTile(
                    enabled: bedtime.enabled,
                    title: const Text('Wind-down reminder'),
                    subtitle: const Text('A heads-up before bedtime.'),
                    trailing: DropdownButton<int>(
                      key: const Key('bedtime-wind-down'),
                      value: bedtime.windDownMinutes,
                      onChanged: !bedtime.enabled
                          ? null
                          : (m) => ref
                                .read(bedtimeProvider.notifier)
                                .change((b) => b.copyWith(windDownMinutes: m)),
                      items: [
                        for (final m in {
                          ...windDownChoices,
                          bedtime.windDownMinutes,
                        })
                          DropdownMenuItem(
                            value: m,
                            child: Text(windDownLabel(m)),
                          ),
                      ],
                    ),
                  ),
                  if (bedtime.quietHoursSupported)
                    SwitchListTile(
                      key: const Key('bedtime-quiet'),
                      title: const Text('Quiet hours'),
                      subtitle: Text(
                        bedtime.quietHoursAllowed
                            ? 'Do Not Disturb from bedtime until your alarm. '
                                  'Alarms still ring.'
                            : 'Do Not Disturb from bedtime until your alarm. '
                                  'Needs Do Not Disturb access (asked once).',
                      ),
                      value: bedtime.quietHours,
                      onChanged: !bedtime.enabled
                          ? null
                          : (on) => ref
                                .read(bedtimeProvider.notifier)
                                .setQuietHours(on),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
