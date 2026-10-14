import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../watch_setup/watch_settings.dart';
import '../watch_setup/watch_setup_screen.dart';
import 'ui_kit.dart';

/// App settings: for now, the smartwatch.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
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
        ],
      ),
    );
  }
}
