import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../watch_setup/watch_settings.dart';
import '../watch_setup/watch_setup_screen.dart';

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
        children: [
          ListTile(
            key: const Key('settings-watch'),
            leading: const Icon(Icons.watch),
            title: const Text('Smartwatch'),
            subtitle: Text(status),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WatchSetupScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
