import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenges/core/capabilities.dart';
import '../challenges/core/challenge.dart';
import '../challenges/core/challenge_id.dart';
import '../challenges/registry.dart';

/// Try any alarm challenge without an alarm ringing.
class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(deviceCapabilitiesProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        children: [
          for (final id in ChallengeId.values)
            Builder(
              builder: (context) {
                final d = definitionFor(id);
                // Tilt maze level 1 needs nothing, so it is always playable.
                final playable =
                    caps == null || caps.containsAll(d.requires(1));
                return ListTile(
                  enabled: playable,
                  title: Text(d.title),
                  subtitle: Text(
                    playable ? d.instructions : 'Not on this phone',
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PracticeRunScreen(id: id),
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
    if (setup != null && !_d.isSetUp(_params)) {
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
                children: [
                  Text(_d.instructions, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Text('Difficulty $_difficulty'),
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
                  ),
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
