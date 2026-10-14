import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../app/ui_kit.dart';
import '../challenges/core/capabilities.dart';
import '../challenges/core/challenge.dart';
import '../challenges/core/challenge_id.dart';
import '../challenges/core/types.dart';
import '../challenges/registry.dart';
import '../watch_setup/watch_settings.dart';
import '../watch_setup/watch_setup_screen.dart';

const _permissionGated = {SensorKind.camera, SensorKind.stepDetector};

/// Try any alarm challenge without an alarm ringing.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(deviceCapabilitiesProvider).value;
    final watch =
        ref.watch(watchSettingsProvider).value ?? const WatchSettings();
    final watchIds = [
      for (final id in ChallengeId.values)
        if (isWatchChallenge(id) &&
            watch.ready &&
            watch.sensors.containsAll(watchSensorsFor(id)))
          id,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final id in [
            for (final id in ChallengeId.values)
              if (!isWatchChallenge(id)) id,
            null, // the watch section starts here
            ...watchIds,
          ])
            if (id == null) ...[
              const SectionHeader(
                Icons.watch_outlined,
                'Watch challenges',
                key: Key('watch-section'),
                padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              ),
              if (watchIds.isEmpty)
                Card(
                  child: ListTile(
                    key: const Key('practice-watch-setup'),
                    leading: const IconBadge(Icons.settings_outlined),
                    title: const Text('Set up your watch first'),
                    subtitle: const Text(
                      'Watch challenges appear here once the watch is tested.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const WatchSetupScreen(),
                      ),
                    ),
                  ),
                ),
            ] else
              Builder(
                builder: (context) {
                  final d = definitionFor(id);
                  // Camera and step counting may only lack a permission, which
                  // the challenge asks for itself, so they stay playable.
                  final missing = caps == null
                      ? const <SensorKind>{}
                      : d.requires(1).difference(caps);
                  final playable = missing.every(_permissionGated.contains);
                  final scheme = Theme.of(context).colorScheme;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                    child: ListTile(
                      enabled: playable,
                      minVerticalPadding: 8,
                      contentPadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                      leading: IconBadge(
                        challengeIcon(id),
                        color: playable
                            ? accentAt(scheme, id.index)
                            : scheme.onSurfaceVariant,
                      ),
                      title: Text(d.title),
                      subtitle: Text(
                        playable ? d.instructions : 'Not on this phone',
                      ),
                      trailing: playable
                          ? Icon(
                              Icons.play_circle_fill_rounded,
                              color: scheme.primary,
                              size: 32,
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PracticeRunScreen(id: id),
                        ),
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}

class PracticeRunScreen extends StatefulWidget {
  const PracticeRunScreen({super.key, required this.id});

  final ChallengeId id;

  @override
  State<PracticeRunScreen> createState() => _PracticeRunScreenState();
}

enum _Run { choosing, playing, passed, unavailable }

class _PracticeRunScreenState extends State<PracticeRunScreen> {
  final _random = Random();
  var _run = _Run.choosing;
  var _difficulty = 3;
  var _params = <String, Object?>{};
  var _attempt = 0;

  ChallengeDefinition get _d => definitionFor(widget.id);

  Future<void> _start() async {
    final setup = _d.setup;
    // First run, or incomplete setup: set the challenge up (steps, light…).
    if (setup != null && (_params.isEmpty || !_d.isSetUp(_params))) {
      final params = await setup(context, _params);
      if (params == null || !mounted) return;
      _params = params;
    }
    setState(() {
      _attempt++;
      _run = _Run.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_d.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: switch (_run) {
              _Run.choosing => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: IconBadge(challengeIcon(widget.id), size: 112)),
                  const SizedBox(height: 24),
                  Text(
                    _d.instructions,
                    textAlign: TextAlign.center,
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Difficulty $_difficulty',
                    textAlign: TextAlign.center,
                    style: text.labelLarge,
                  ),
                  Slider(
                    value: _difficulty.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_difficulty',
                    onChanged: (v) => setState(() => _difficulty = v.round()),
                  ),
                  FilledButton(onPressed: _start, child: const Text('Start')),
                ],
              ),
              _Run.playing => KeyedSubtree(
                key: ValueKey(_attempt),
                child: _d.build(
                  ChallengeArgs(
                    difficulty: _difficulty,
                    random: _random,
                    params: _params,
                    onPassed: () => setState(() => _run = _Run.passed),
                    onUnavailable: () =>
                        setState(() => _run = _Run.unavailable),
                  ),
                ),
              ),
              _Run.passed || _Run.unavailable => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _run == _Run.passed ? Icons.verified : Icons.sensors_off,
                    size: 96,
                    color: _run == _Run.passed
                        ? SunriseColors.of(context).success
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _run == _Run.passed ? 'Passed!' : 'Not available right now',
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _run = _Run.choosing),
                    child: const Text('Again'),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
