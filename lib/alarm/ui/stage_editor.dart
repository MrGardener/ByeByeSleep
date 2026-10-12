import 'dart:math';

import 'package:flutter/material.dart';

import '../../challenges/core/challenge.dart';
import '../../challenges/core/challenge_id.dart';
import '../../challenges/registry.dart';
import '../stage_config.dart';

const maxStages = 6;

/// Ordered list of an alarm's stages: reorder, set difficulty, add, remove,
/// and practise each one.
class StageEditor extends StatelessWidget {
  const StageEditor({super.key, required this.stages, required this.onChanged});

  final List<StageConfig> stages;
  final ValueChanged<List<StageConfig>> onChanged;

  void _replace(int i, StageConfig s) => onChanged([...stages]..[i] = s);

  Future<void> _setup(BuildContext context, int i) async {
    final setup = definitionFor(stages[i].challenge).setup;
    if (setup == null) return;
    final params = await setup(context, stages[i].params);
    if (params != null) _replace(i, stages[i].copyWith(params: params));
  }

  /// Switches to the wake-up routine, keeping setup already done for the
  /// same challenges.
  void _useRoutine() => onChanged([
    for (final r in wakeUpRoutine)
      stages
              .where((s) => s.challenge == r.challenge && s.params.isNotEmpty)
              .firstOrNull ??
          r,
  ]);

  Future<void> _add(BuildContext context) async {
    final picked = await showModalBottomSheet<ChallengeId>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final id in ChallengeId.values)
            ListTile(
              key: Key('pick-${id.name}'),
              title: Text(definitionFor(id).title),
              subtitle: Text(definitionFor(id).instructions),
              onTap: () => Navigator.of(context).pop(id),
            ),
        ],
      ),
    );
    if (picked != null) onChanged([...stages, StageConfig(picked)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Stages — Stop and Snooze appear after the last one',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          onReorderItem: (from, to) {
            final list = [...stages];
            list.insert(to, list.removeAt(from));
            onChanged(list);
          },
          children: [
            for (var i = 0; i < stages.length; i++)
              Card(
                key: ValueKey('stage-row-$i'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 40, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(radius: 12, child: Text('${i + 1}')),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              definitionFor(stages[i].challenge).title,
                            ),
                          ),
                          if (!definitionFor(stages[i].challenge)
                              .isSetUp(stages[i].params))
                            Chip(
                              key: Key('needs-setup-$i'),
                              label: const Text('Needs setup'),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (definitionFor(stages[i].challenge).setup != null)
                            IconButton(
                              key: Key('setup-stage-$i'),
                              tooltip: 'Set up',
                              icon: const Icon(Icons.tune),
                              onPressed: () => _setup(context, i),
                            ),
                          IconButton(
                            key: Key('try-stage-$i'),
                            tooltip: 'Try it',
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    PracticeScreen(stage: stages[i]),
                              ),
                            ),
                          ),
                          IconButton(
                            key: Key('remove-stage-$i'),
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: stages.length > 1
                                ? () => onChanged([...stages]..removeAt(i))
                                : null,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Difficulty ${stages[i].difficulty}'),
                          Expanded(
                            child: Slider(
                              key: Key('difficulty-$i'),
                              value: stages[i].difficulty.toDouble(),
                              min: 1,
                              max: 5,
                              divisions: 4,
                              label: '${stages[i].difficulty}',
                              onChanged: (v) => _replace(
                                i,
                                stages[i].copyWith(difficulty: v.round()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Wrap(
          children: [
            TextButton.icon(
              key: const Key('use-routine'),
              onPressed: _useRoutine,
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Use wake-up routine'),
            ),
          ],
        ),
        TextButton.icon(
          key: const Key('add-stage'),
          onPressed: stages.length < maxStages ? () => _add(context) : null,
          icon: const Icon(Icons.add),
          label: const Text('Add stage'),
        ),
      ],
    );
  }
}

/// Plays one challenge without an alarm, to learn it while awake.
class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.stage});

  final StageConfig stage;

  @override
  Widget build(BuildContext context) {
    final definition = definitionFor(stage.challenge);
    return Scaffold(
      appBar: AppBar(title: Text('Practice: ${definition.title}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(definition.instructions),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: definition.build(
                  ChallengeArgs(
                    difficulty: stage.difficulty,
                    random: Random(),
                    params: stage.params,
                    onPassed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Passed! 🎉')),
                      );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
