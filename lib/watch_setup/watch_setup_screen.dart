import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenges/core/capabilities.dart';
import '../challenges/core/types.dart';
import '../challenges/core/watch.dart';
import '../app/theme.dart';
import '../app/ui_kit.dart';
import 'watch_settings.dart';

enum _Step { ask, install, test }

/// Asks whether the owner has a watch, explains how to install the watch
/// app, and tests it live: only sensors that really send readings unlock
/// watch challenges. Nothing that needs a watch is offered before this.
class WatchSetupScreen extends ConsumerStatefulWidget {
  const WatchSetupScreen({super.key});

  @override
  ConsumerState<WatchSetupScreen> createState() => _WatchSetupScreenState();
}

class _WatchSetupScreenState extends ConsumerState<WatchSetupScreen> {
  var _step = _Step.ask;
  bool? _connected;
  final _seen = <SensorKind>{};
  StreamSubscription<WatchReading>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _save(WatchSettings s) async {
    await ref.read(watchSettingsProvider.notifier).set(s);
    ref.invalidate(deviceCapabilitiesProvider);
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _test() async {
    setState(() {
      _step = _Step.test;
      _connected = null;
      _seen.clear();
    });
    await _sub?.cancel();
    final watch = ref.read(watchSourceProvider);
    final ok = await watch.available();
    if (!mounted) return;
    setState(() => _connected = ok);
    if (!ok) return;
    _sub = watch.readings.listen((r) {
      final kind = switch (r) {
        HeartRateReading() => SensorKind.heartRate,
        MotionReading() => SensorKind.watchMotion,
        StepsReading() => SensorKind.watchSteps,
      };
      if (mounted) setState(() => _seen.add(kind));
    });
  }

  Widget _check(String key, String label, bool? done, {String? hint}) =>
      ListTile(
        key: Key('check-$key-${done == true ? 'done' : 'todo'}'),
        leading: Icon(
          done == true ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done == true ? SunriseColors.of(context).success : null,
        ),
        title: Text(label),
        subtitle: hint == null ? null : Text(hint),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Smartwatch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: switch (_step) {
          _Step.ask => [
            const SizedBox(height: 8),
            const Center(child: IconBadge(Icons.watch_outlined, size: 112)),
            const SizedBox(height: 24),
            Text(
              'Do you have a smartwatch you want to use with ByeByeSleep?',
              style: text.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Some challenges read your heart rate, wrist movement or steps '
              'from the watch. They are only offered once the watch is set '
              'up and tested here — an alarm never asks for a watch you do '
              'not have.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('watch-yes'),
              onPressed: () => setState(() => _step = _Step.install),
              child: const Text('Yes, set up my watch'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('watch-no'),
              onPressed: () =>
                  _save(const WatchSettings(choice: WatchChoice.none)),
              child: const Text('No watch — hide watch challenges'),
            ),
          ],
          _Step.install => [
            Text('1. Install the watch app', style: text.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Works with Wear OS watches: Pixel Watch 3 (tested target), '
              'other Pixel Watches, Samsung Galaxy Watch 4 or newer. Fitbit '
              'trackers cannot run it.\n\n'
              'Install ByeByeSleep-watch.apk on the watch once from a '
              'computer (steps in docs/watch-install.md on GitHub), open it '
              'on the watch and allow body sensors and physical activity.',
            ),
            const SizedBox(height: 16),
            Text('2. Test it', style: text.titleLarge),
            const Text(
              'Wear the watch. The test opens ByeByeSleep on it and waits for '
              'readings.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('watch-test'),
              onPressed: _test,
              child: const Text('I installed it — test now'),
            ),
          ],
          _Step.test => [
            _check(
              'connected',
              'Watch found',
              _connected,
              hint: _connected == false
                  ? 'Watch not found. Is it paired with this phone, nearby, '
                        'and is the watch app installed?'
                  : null,
            ),
            _check(
              'heartRate',
              'Heart rate',
              _seen.contains(SensorKind.heartRate),
              hint: 'Wear the watch snugly.',
            ),
            _check(
              'watchMotion',
              'Wrist movement',
              _seen.contains(SensorKind.watchMotion),
              hint: 'Move your arm.',
            ),
            _check(
              'watchSteps',
              'Steps',
              _seen.contains(SensorKind.watchSteps),
              hint: 'Walk a few steps.',
            ),
            const SizedBox(height: 16),
            if (_seen.isNotEmpty)
              FilledButton(
                key: const Key('watch-save'),
                onPressed: () => _save(
                  WatchSettings(
                    choice: WatchChoice.verified,
                    sensors: {..._seen},
                  ),
                ),
                child: Text(
                  'Use the watch (${_seen.length} of 3 sensors working)',
                ),
              ),
            TextButton(onPressed: _test, child: const Text('Test again')),
          ],
        },
      ),
    );
  }
}
