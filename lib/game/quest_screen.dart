import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../app/ui_kit.dart';
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor Quest')),
      body: switch ((progress, caps)) {
        (AsyncData(value: final done), AsyncData(value: final caps)) => ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            HeroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_outlined, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Play with every sensor in your phone',
                          style: text.titleMedium?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${done.length} of ${World.values.length} worlds complete',
                    style: text.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: done.length / World.values.length,
                    color: Sunrise.amber,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                  ),
                ],
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
    final scheme = Theme.of(context).colorScheme;
    final playable =
        status == WorldStatus.open || status == WorldStatus.completed;
    final (icon, label) = switch (status) {
      WorldStatus.open => (Icons.play_arrow_rounded, 'Play'),
      WorldStatus.completed => (Icons.check_rounded, 'Done'),
      WorldStatus.locked => (Icons.lock_outline, 'Locked'),
      WorldStatus.unsupported => (Icons.block, 'Not on this phone'),
    };
    final (pillBg, pillFg) = switch (status) {
      WorldStatus.open => (scheme.primary, scheme.onPrimary),
      WorldStatus.completed => (
        SunriseColors.of(context).success,
        SunriseColors.of(context).onSuccess,
      ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Card(
      color: status == WorldStatus.open
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerHigh,
      child: ListTile(
        enabled: playable,
        contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        leading: IconBadge(
          worldIcon(world),
          size: 52,
          color: playable
              ? accentAt(scheme, world.index)
              : scheme.onSurfaceVariant,
        ),
        title: Text(world.title),
        subtitle: Text(world.blurb),
        trailing: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: ShapeDecoration(
            color: pillBg,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: pillFg),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 72),
                child: Text(
                  label,
                  key: Key('world-${world.name}-status'),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: pillFg),
                ),
              ),
            ],
          ),
        ),
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
