import 'package:byebyesleep/tools/world_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 22:41 local in a UTC+2 zone = 20:41 UTC.
  final now = DateTime.utc(2026, 10, 14, 20, 41);
  const localOffset = Duration(hours: 2);

  test('time in a city from its offset', () {
    final tokyo = cityTime(now, const Duration(hours: 9), localOffset);
    expect(tokyo.time, '05:41');
    expect(tokyo.dayLabel, 'Tomorrow');
    expect(tokyo.difference, '+7 h');
    final ny = cityTime(now, const Duration(hours: -4), localOffset);
    expect(ny.time, '16:41');
    expect(ny.dayLabel, 'Today');
    expect(ny.difference, '−6 h');
    final delhi = cityTime(
      now,
      const Duration(hours: 5, minutes: 30),
      localOffset,
    );
    expect(delhi.time, '02:11');
    expect(delhi.difference, '+3 h 30 min');
    final same = cityTime(now, localOffset, localOffset);
    expect(same.difference, 'Same time');
  });

  test('yesterday when behind across midnight', () {
    final early = DateTime.utc(2026, 10, 14, 1, 0); // 03:00 local (UTC+2)
    expect(
      cityTime(early, const Duration(hours: -7), localOffset).dayLabel,
      'Yesterday',
    );
  });

  test('city search ignores case and accents', () {
    expect(searchCities('tok').map((c) => c.name), contains('Tokyo'));
    expect(searchCities('SAO').map((c) => c.name), contains('São Paulo'));
    expect(searchCities('zzz'), isEmpty);
    expect(
      worldCities.map((c) => c.zone).toSet(),
      hasLength(worldCities.length),
    );
  });
}
