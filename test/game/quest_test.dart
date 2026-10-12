import 'package:byebyesleep/challenges/core/types.dart';
import 'package:byebyesleep/game/quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final all = SensorKind.values.toSet();

  test('first world is open on a fresh start, the rest locked', () {
    expect(worldStatus(World.batteryOracle, {}, all), WorldStatus.open);
    expect(worldStatus(World.labyrinth, {}, all), WorldStatus.locked);
  });

  test('completing a world opens the next', () {
    final done = {World.batteryOracle};
    expect(worldStatus(World.batteryOracle, done, all), WorldStatus.completed);
    expect(worldStatus(World.labyrinth, done, all), WorldStatus.open);
    expect(worldStatus(World.compassTemple, done, all), WorldStatus.locked);
  });

  test('a world this phone cannot play does not block the next', () {
    final caps = all.difference({SensorKind.barometer});
    final done = {
      World.batteryOracle,
      World.labyrinth,
      World.compassTemple,
      World.solarGarden,
      World.ghostHide,
    };
    expect(worldStatus(World.skyTower, done, caps), WorldStatus.unsupported);
    expect(worldStatus(World.runeHunt, done, caps), WorldStatus.open);
  });

  test('worlds are in the spec order and each has a title', () {
    expect(World.values.first, World.batteryOracle);
    expect(World.batteryOracle.requires, {SensorKind.battery});
    for (final w in World.values) {
      expect(w.title, isNotEmpty);
      expect(w.blurb, isNotEmpty);
    }
  });
}
