/// Sensor Quest worlds and the rule that unlocks them (spec §7). Pure Dart.
library;

import '../challenges/core/types.dart';

enum World {
  batteryOracle('Battery Oracle', 'Guess the battery level without looking.', {
    SensorKind.battery,
  }),
  labyrinth('Labyrinth', 'Three tilt mazes, each harder than the last.', {
    SensorKind.accelerometer,
    SensorKind.gyroscope,
  }),
  compassTemple('Compass Temple', 'Face each rune direction and hold still.', {
    SensorKind.accelerometer,
    SensorKind.magnetometer,
  }),
  solarGarden('Solar Garden', 'Grow the plant with real light.', {
    SensorKind.light,
  }),
  ghostHide('Ghost Hide', 'Cover the top of the phone when the ghost looks.', {
    SensorKind.proximity,
  }),
  skyTower('Sky Tower', 'Climb a real floor of stairs.', {
    SensorKind.barometer,
  }),
  runeHunt('Rune Hunt', 'Touch three different NFC stickers.', {
    SensorKind.nfc,
  });

  const World(this.title, this.blurb, this.requires);

  final String title;
  final String blurb;
  final Set<SensorKind> requires;
}

enum WorldStatus { locked, open, completed, unsupported }

/// A world opens once every earlier world is completed or unplayable here.
WorldStatus worldStatus(World w, Set<World> completed, Set<SensorKind> caps) {
  if (!caps.containsAll(w.requires)) return WorldStatus.unsupported;
  if (completed.contains(w)) return WorldStatus.completed;
  final earlierDone = World.values
      .take(w.index)
      .every((e) => completed.contains(e) || !caps.containsAll(e.requires));
  return earlierDone ? WorldStatus.open : WorldStatus.locked;
}
