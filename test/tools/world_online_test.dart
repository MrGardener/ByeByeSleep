import 'package:byebyesleep/tools/world_clock.dart';
import 'package:flutter_test/flutter_test.dart';

const _geo = '''
{"results":[
 {"id":2643743,"name":"London","latitude":51.50853,"longitude":-0.12574,
  "country":"United Kingdom","admin1":"England","timezone":"Europe/London"},
 {"id":6058560,"name":"London","latitude":42.98339,"longitude":-81.23304,
  "country":"Canada","admin1":"Ontario","timezone":"America/Toronto"},
 {"id":1,"name":"Nowhere","latitude":0,"longitude":0,"country":"X"}
]}''';

const _weather = '''
{"current":{"time":"2026-10-14T21:00","temperature_2m":12.6,"weather_code":61,"is_day":0}}''';

void main() {
  test('Open-Meteo search results become cities with their time zone', () {
    final cities = parseGeocoding(_geo);
    expect(cities, hasLength(2)); // no time zone, no clock
    expect(cities.first.name, 'London');
    expect(cities.first.region, 'England, United Kingdom');
    expect(cities.first.zone, 'Europe/London');
    expect(cities[1].zone, 'America/Toronto');
    expect(cities.first.latitude, closeTo(51.5, 0.01));
  });

  test('current weather from Open-Meteo', () {
    final w = parseWeather(_weather)!;
    expect(w.temperatureC, closeTo(12.6, 0.01));
    expect(w.description, 'Rain');
    expect(w.isDay, isFalse);
    expect(w.temperatureText(fahrenheit: false), '13°');
    expect(w.temperatureText(fahrenheit: true), '55°');
    expect(parseWeather('{}'), isNull);
  });

  test('weather codes have words and icons', () {
    expect(weatherDescription(0), 'Clear');
    expect(weatherDescription(3), 'Cloudy');
    expect(weatherDescription(45), 'Fog');
    expect(weatherDescription(71), 'Snow');
    expect(weatherDescription(95), 'Thunderstorm');
  });

  test('a city round-trips through json; old saved zones still load', () {
    const c = City(
      'Tokyo',
      'Japan',
      'Asia/Tokyo',
      latitude: 35.68,
      longitude: 139.69,
    );
    expect(City.fromJson(c.toJson()).zone, 'Asia/Tokyo');
    expect(City.fromJson(c.toJson()).latitude, 35.68);
    // Earlier versions saved only the zone id.
    expect(City.fromSaved('Asia/Tokyo')!.name, 'Tokyo');
    expect(City.fromSaved('Not/AZone'), isNull);
  });

  test('built-in cities all have coordinates for the weather', () {
    expect(worldCities.length, greaterThanOrEqualTo(100));
    expect(
      worldCities.every((c) => c.latitude != null && c.longitude != null),
      isTrue,
    );
  });
}
