import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../challenges/core/challenge.dart';
import '../challenges/heart_rate/widget.dart';
import 'progress_store.dart';
import 'quest.dart';
import 'worlds/battery_oracle.dart';
import 'worlds/compass_temple.dart';
import 'worlds/ghost_hide.dart';
import 'worlds/labyrinth.dart';
import 'worlds/rune_hunt.dart';
import 'worlds/sky_tower.dart';
import 'worlds/solar_garden.dart';
import 'worlds/world_kit.dart';

Widget buildWorld(World w, WorldArgs args) => switch (w) {
  World.batteryOracle => BatteryOracleWorld(
    onPassed: args.onPassed,
    onUnavailable: args.onUnavailable,
  ),
  World.labyrinth => LabyrinthWorld(args: args),
  World.compassTemple => CompassTempleWorld(args: args),
  World.solarGarden => SolarGardenWorld(args: args),
  World.ghostHide => GhostHideWorld(args: args),
  World.skyTower => SkyTowerWorld(args: args),
  World.runeHunt => RuneHuntWorld(args: args),
  World.pulseRun => HeartRateChallenge(
    args: ChallengeArgs(
      difficulty: 2,
      random: Random(),
      onPassed: args.onPassed,
      onUnavailable: args.onUnavailable,
    ),
  ),
};

enum _Outcome { playing, won, unavailable }

/// Plays one world; on a win, saves it and offers the way back.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key, required this.world});

  final World world;

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  var _outcome = _Outcome.playing;

  void _won() {
    ref
        .read(questProgressProvider.notifier)
        .complete(widget.world)
        .catchError((Object _) {}); // shown as done; saved next time
    setState(() => _outcome = _Outcome.won);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget end(IconData icon, String title, String detail) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 96, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: 8),
        Text(title, style: text.headlineMedium),
        const SizedBox(height: 4),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: text.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to the map'),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.world.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: switch (_outcome) {
              _Outcome.playing => Column(
                children: [
                  Text(widget.world.blurb, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: buildWorld(
                        widget.world,
                        WorldArgs(
                          onPassed: _won,
                          onUnavailable: () =>
                              setState(() => _outcome = _Outcome.unavailable),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _Outcome.won => end(
                Icons.emoji_events,
                'World complete!',
                widget.world == World.values.last
                    ? 'You finished every world!'
                    : 'Well played.',
              ),
              _Outcome.unavailable => end(
                Icons.sensors_off,
                'Sensor not answering',
                'This world needs a sensor that is not responding right now.',
              ),
            },
          ),
        ),
      ),
    );
  }
}
