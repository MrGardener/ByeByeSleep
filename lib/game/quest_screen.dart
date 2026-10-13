import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenges/core/capabilities.dart';
import 'progress_store.dart';
import 'quest.dart';
import 'world_screen.dart';

/// The Sensor Quest map: every world with its status.
class QuestScreen extends ConsumerWidget {
  const QuestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(questProgressProvider);
    final caps = ref.watch(deviceCapabilitiesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Quest')),
      body: switch ((progress, caps)) {
        (AsyncData(value: final done), AsyncData(value: final caps)) =>
          ListView(
            padding: const EdgeInsets.all(8),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${done.length} of ${World.values.length} worlds complete',
                ),
              ),
              for (final w in World.values)
                _WorldCard(world: w, status: worldStatus(w, done, caps)),
            ],
          ),
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          Center(child: Text('Could not load the quest: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world, required this.status});

  final World world;
  final WorldStatus status;

  @override
  Widget build(BuildContext context) {
    final playable =
        status == WorldStatus.open || status == WorldStatus.completed;
    final (icon, label) = switch (status) {
      WorldStatus.open => (Icons.play_circle, 'Play'),
      WorldStatus.completed => (Icons.check_circle, 'Done'),
      WorldStatus.locked => (Icons.lock, 'Locked'),
      WorldStatus.unsupported => (Icons.block, 'Not on this phone'),
    };
    return Card(
      child: ListTile(
        enabled: playable,
        leading: Icon(icon, size: 32),
        title: Text(world.title),
        subtitle: Text(world.blurb),
        trailing: Text(label, key: Key('world-${world.name}-status')),
        onTap: playable
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WorldScreen(world: world),
                ),
              )
            : null,
      ),
    );
  }
}
