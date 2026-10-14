import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class City {
  const City(
    this.name,
    this.country,
    this.zone, {
    this.latitude,
    this.longitude,
    this.region,
  });

  factory City.fromJson(Map<String, Object?> j) => City(
    j['name']! as String,
    j['country'] as String? ?? '',
    j['zone']! as String,
    latitude: (j['lat'] as num?)?.toDouble(),
    longitude: (j['lon'] as num?)?.toDouble(),
    region: j['region'] as String?,
  );

  /// A saved entry: a city object, or (earlier versions) a bare zone id.
  static City? fromSaved(Object? saved) {
    if (saved is Map) {
      try {
        return City.fromJson(saved.cast<String, Object?>());
      } catch (_) {
        return null;
      }
    }
    return saved is String ? cityForZone(saved) : null;
  }

  final String name;
  final String country;

  /// IANA time zone, e.g. Europe/Paris.
  final String zone;
  final double? latitude;
  final double? longitude;

  /// "England, United Kingdom" for search results; the country otherwise.
  final String? region;

  String get place => region ?? country;

  /// Unique per city (several cities share a zone).
  String get id => '$name@$zone';

  Map<String, Object?> toJson() => {
    'name': name,
    'country': country,
    'zone': zone,
    'lat': ?latitude,
    'lon': ?longitude,
    'region': ?region,
  };
}

/// Built in: works offline and opens instantly. Any other city comes from
/// the online search (Open-Meteo, free, the same service as the weather).
const worldCities = [
  City(
    'Honolulu',
    'USA',
    'Pacific/Honolulu',
    latitude: 21.31,
    longitude: -157.86,
  ),
  City(
    'Anchorage',
    'USA',
    'America/Anchorage',
    latitude: 61.22,
    longitude: -149.90,
  ),
  City(
    'Los Angeles',
    'USA',
    'America/Los_Angeles',
    latitude: 34.05,
    longitude: -118.24,
  ),
  City(
    'San Francisco',
    'USA',
    'America/Los_Angeles',
    latitude: 37.77,
    longitude: -122.42,
  ),
  City(
    'Seattle',
    'USA',
    'America/Los_Angeles',
    latitude: 47.61,
    longitude: -122.33,
  ),
  City(
    'Las Vegas',
    'USA',
    'America/Los_Angeles',
    latitude: 36.17,
    longitude: -115.14,
  ),
  City(
    'Vancouver',
    'Canada',
    'America/Vancouver',
    latitude: 49.28,
    longitude: -123.12,
  ),
  City(
    'Phoenix',
    'USA',
    'America/Phoenix',
    latitude: 33.45,
    longitude: -112.07,
  ),
  City('Denver', 'USA', 'America/Denver', latitude: 39.74, longitude: -104.99),
  City(
    'Calgary',
    'Canada',
    'America/Edmonton',
    latitude: 51.05,
    longitude: -114.07,
  ),
  City(
    'Mexico City',
    'Mexico',
    'America/Mexico_City',
    latitude: 19.43,
    longitude: -99.13,
  ),
  City(
    'Guadalajara',
    'Mexico',
    'America/Mexico_City',
    latitude: 20.66,
    longitude: -103.35,
  ),
  City(
    'Monterrey',
    'Mexico',
    'America/Monterrey',
    latitude: 25.69,
    longitude: -100.32,
  ),
  City(
    'Cancún',
    'Mexico',
    'America/Cancun',
    latitude: 21.16,
    longitude: -86.85,
  ),
  City('Chicago', 'USA', 'America/Chicago', latitude: 41.88, longitude: -87.63),
  City('Houston', 'USA', 'America/Chicago', latitude: 29.76, longitude: -95.37),
  City('Dallas', 'USA', 'America/Chicago', latitude: 32.78, longitude: -96.80),
  City(
    'Winnipeg',
    'Canada',
    'America/Winnipeg',
    latitude: 49.90,
    longitude: -97.14,
  ),
  City(
    'Guatemala City',
    'Guatemala',
    'America/Guatemala',
    latitude: 14.63,
    longitude: -90.51,
  ),
  City(
    'San José',
    'Costa Rica',
    'America/Costa_Rica',
    latitude: 9.93,
    longitude: -84.08,
  ),
  City(
    'Panama City',
    'Panama',
    'America/Panama',
    latitude: 8.98,
    longitude: -79.52,
  ),
  City(
    'New York',
    'USA',
    'America/New_York',
    latitude: 40.71,
    longitude: -74.01,
  ),
  City(
    'Washington',
    'USA',
    'America/New_York',
    latitude: 38.91,
    longitude: -77.04,
  ),
  City('Boston', 'USA', 'America/New_York', latitude: 42.36, longitude: -71.06),
  City('Miami', 'USA', 'America/New_York', latitude: 25.76, longitude: -80.19),
  City(
    'Atlanta',
    'USA',
    'America/New_York',
    latitude: 33.75,
    longitude: -84.39,
  ),
  City('Detroit', 'USA', 'America/Detroit', latitude: 42.33, longitude: -83.05),
  City(
    'Toronto',
    'Canada',
    'America/Toronto',
    latitude: 43.65,
    longitude: -79.38,
  ),
  City(
    'Montreal',
    'Canada',
    'America/Toronto',
    latitude: 45.50,
    longitude: -73.57,
  ),
  City('Havana', 'Cuba', 'America/Havana', latitude: 23.11, longitude: -82.37),
  City(
    'Kingston',
    'Jamaica',
    'America/Jamaica',
    latitude: 17.97,
    longitude: -76.79,
  ),
  City(
    'Santo Domingo',
    'Dominican Republic',
    'America/Santo_Domingo',
    latitude: 18.49,
    longitude: -69.93,
  ),
  City(
    'San Juan',
    'Puerto Rico',
    'America/Puerto_Rico',
    latitude: 18.47,
    longitude: -66.11,
  ),
  City(
    'Bogotá',
    'Colombia',
    'America/Bogota',
    latitude: 4.71,
    longitude: -74.07,
  ),
  City(
    'Medellín',
    'Colombia',
    'America/Bogota',
    latitude: 6.24,
    longitude: -75.58,
  ),
  City('Lima', 'Peru', 'America/Lima', latitude: -12.05, longitude: -77.04),
  City(
    'Quito',
    'Ecuador',
    'America/Guayaquil',
    latitude: -0.18,
    longitude: -78.47,
  ),
  City(
    'Caracas',
    'Venezuela',
    'America/Caracas',
    latitude: 10.48,
    longitude: -66.90,
  ),
  City(
    'La Paz',
    'Bolivia',
    'America/La_Paz',
    latitude: -16.50,
    longitude: -68.15,
  ),
  City(
    'Santiago',
    'Chile',
    'America/Santiago',
    latitude: -33.45,
    longitude: -70.67,
  ),
  City(
    'Halifax',
    'Canada',
    'America/Halifax',
    latitude: 44.65,
    longitude: -63.58,
  ),
  City(
    'Buenos Aires',
    'Argentina',
    'America/Argentina/Buenos_Aires',
    latitude: -34.60,
    longitude: -58.38,
  ),
  City(
    'Montevideo',
    'Uruguay',
    'America/Montevideo',
    latitude: -34.90,
    longitude: -56.16,
  ),
  City(
    'Asunción',
    'Paraguay',
    'America/Asuncion',
    latitude: -25.26,
    longitude: -57.58,
  ),
  City(
    'São Paulo',
    'Brazil',
    'America/Sao_Paulo',
    latitude: -23.55,
    longitude: -46.63,
  ),
  City(
    'Rio de Janeiro',
    'Brazil',
    'America/Sao_Paulo',
    latitude: -22.91,
    longitude: -43.17,
  ),
  City(
    'Brasília',
    'Brazil',
    'America/Sao_Paulo',
    latitude: -15.79,
    longitude: -47.88,
  ),
  City(
    'St. John\'s',
    'Canada',
    'America/St_Johns',
    latitude: 47.56,
    longitude: -52.71,
  ),
  City('Nuuk', 'Greenland', 'America/Nuuk', latitude: 64.18, longitude: -51.72),
  City(
    'Azores',
    'Portugal',
    'Atlantic/Azores',
    latitude: 37.74,
    longitude: -25.67,
  ),
  City(
    'Reykjavík',
    'Iceland',
    'Atlantic/Reykjavik',
    latitude: 64.15,
    longitude: -21.94,
  ),
  City('Dakar', 'Senegal', 'Africa/Dakar', latitude: 14.72, longitude: -17.47),
  City(
    'Casablanca',
    'Morocco',
    'Africa/Casablanca',
    latitude: 33.57,
    longitude: -7.59,
  ),
  City(
    'London',
    'United Kingdom',
    'Europe/London',
    latitude: 51.51,
    longitude: -0.13,
  ),
  City('Dublin', 'Ireland', 'Europe/Dublin', latitude: 53.35, longitude: -6.26),
  City(
    'Lisbon',
    'Portugal',
    'Europe/Lisbon',
    latitude: 38.72,
    longitude: -9.14,
  ),
  City('Accra', 'Ghana', 'Africa/Accra', latitude: 5.60, longitude: -0.19),
  City('Madrid', 'Spain', 'Europe/Madrid', latitude: 40.42, longitude: -3.70),
  City('Barcelona', 'Spain', 'Europe/Madrid', latitude: 41.39, longitude: 2.17),
  City('Paris', 'France', 'Europe/Paris', latitude: 48.86, longitude: 2.35),
  City(
    'Brussels',
    'Belgium',
    'Europe/Brussels',
    latitude: 50.85,
    longitude: 4.35,
  ),
  City(
    'Amsterdam',
    'Netherlands',
    'Europe/Amsterdam',
    latitude: 52.37,
    longitude: 4.90,
  ),
  City('Berlin', 'Germany', 'Europe/Berlin', latitude: 52.52, longitude: 13.40),
  City('Munich', 'Germany', 'Europe/Berlin', latitude: 48.14, longitude: 11.58),
  City(
    'Zurich',
    'Switzerland',
    'Europe/Zurich',
    latitude: 47.38,
    longitude: 8.54,
  ),
  City('Vienna', 'Austria', 'Europe/Vienna', latitude: 48.21, longitude: 16.37),
  City('Rome', 'Italy', 'Europe/Rome', latitude: 41.90, longitude: 12.50),
  City('Milan', 'Italy', 'Europe/Rome', latitude: 45.46, longitude: 9.19),
  City('Prague', 'Czechia', 'Europe/Prague', latitude: 50.08, longitude: 14.44),
  City('Warsaw', 'Poland', 'Europe/Warsaw', latitude: 52.23, longitude: 21.01),
  City(
    'Copenhagen',
    'Denmark',
    'Europe/Copenhagen',
    latitude: 55.68,
    longitude: 12.57,
  ),
  City('Oslo', 'Norway', 'Europe/Oslo', latitude: 59.91, longitude: 10.75),
  City(
    'Stockholm',
    'Sweden',
    'Europe/Stockholm',
    latitude: 59.33,
    longitude: 18.07,
  ),
  City(
    'Budapest',
    'Hungary',
    'Europe/Budapest',
    latitude: 47.50,
    longitude: 19.04,
  ),
  City('Lagos', 'Nigeria', 'Africa/Lagos', latitude: 6.52, longitude: 3.38),
  City(
    'Kinshasa',
    'DR Congo',
    'Africa/Kinshasa',
    latitude: -4.44,
    longitude: 15.27,
  ),
  City('Tunis', 'Tunisia', 'Africa/Tunis', latitude: 36.81, longitude: 10.18),
  City(
    'Helsinki',
    'Finland',
    'Europe/Helsinki',
    latitude: 60.17,
    longitude: 24.94,
  ),
  City('Athens', 'Greece', 'Europe/Athens', latitude: 37.98, longitude: 23.73),
  City(
    'Bucharest',
    'Romania',
    'Europe/Bucharest',
    latitude: 44.43,
    longitude: 26.10,
  ),
  City('Kyiv', 'Ukraine', 'Europe/Kyiv', latitude: 50.45, longitude: 30.52),
  City('Cairo', 'Egypt', 'Africa/Cairo', latitude: 30.04, longitude: 31.24),
  City(
    'Johannesburg',
    'South Africa',
    'Africa/Johannesburg',
    latitude: -26.20,
    longitude: 28.05,
  ),
  City(
    'Cape Town',
    'South Africa',
    'Africa/Johannesburg',
    latitude: -33.92,
    longitude: 18.42,
  ),
  City(
    'Jerusalem',
    'Israel',
    'Asia/Jerusalem',
    latitude: 31.77,
    longitude: 35.21,
  ),
  City('Beirut', 'Lebanon', 'Asia/Beirut', latitude: 33.89, longitude: 35.50),
  City(
    'Istanbul',
    'Türkiye',
    'Europe/Istanbul',
    latitude: 41.01,
    longitude: 28.98,
  ),
  City('Moscow', 'Russia', 'Europe/Moscow', latitude: 55.76, longitude: 37.62),
  City('Nairobi', 'Kenya', 'Africa/Nairobi', latitude: -1.29, longitude: 36.82),
  City(
    'Addis Ababa',
    'Ethiopia',
    'Africa/Addis_Ababa',
    latitude: 9.03,
    longitude: 38.74,
  ),
  City(
    'Riyadh',
    'Saudi Arabia',
    'Asia/Riyadh',
    latitude: 24.71,
    longitude: 46.68,
  ),
  City('Doha', 'Qatar', 'Asia/Qatar', latitude: 25.29, longitude: 51.53),
  City('Baghdad', 'Iraq', 'Asia/Baghdad', latitude: 33.31, longitude: 44.36),
  City('Tehran', 'Iran', 'Asia/Tehran', latitude: 35.69, longitude: 51.39),
  City('Dubai', 'UAE', 'Asia/Dubai', latitude: 25.20, longitude: 55.27),
  City('Abu Dhabi', 'UAE', 'Asia/Dubai', latitude: 24.45, longitude: 54.38),
  City('Baku', 'Azerbaijan', 'Asia/Baku', latitude: 40.41, longitude: 49.87),
  City('Kabul', 'Afghanistan', 'Asia/Kabul', latitude: 34.56, longitude: 69.21),
  City(
    'Karachi',
    'Pakistan',
    'Asia/Karachi',
    latitude: 24.86,
    longitude: 67.01,
  ),
  City(
    'Tashkent',
    'Uzbekistan',
    'Asia/Tashkent',
    latitude: 41.30,
    longitude: 69.24,
  ),
  City('Delhi', 'India', 'Asia/Kolkata', latitude: 28.61, longitude: 77.21),
  City('Mumbai', 'India', 'Asia/Kolkata', latitude: 19.08, longitude: 72.88),
  City('Bengaluru', 'India', 'Asia/Kolkata', latitude: 12.97, longitude: 77.59),
  City(
    'Colombo',
    'Sri Lanka',
    'Asia/Colombo',
    latitude: 6.93,
    longitude: 79.86,
  ),
  City(
    'Kathmandu',
    'Nepal',
    'Asia/Kathmandu',
    latitude: 27.72,
    longitude: 85.32,
  ),
  City('Dhaka', 'Bangladesh', 'Asia/Dhaka', latitude: 23.81, longitude: 90.41),
  City(
    'Almaty',
    'Kazakhstan',
    'Asia/Almaty',
    latitude: 43.24,
    longitude: 76.89,
  ),
  City('Yangon', 'Myanmar', 'Asia/Yangon', latitude: 16.87, longitude: 96.20),
  City(
    'Bangkok',
    'Thailand',
    'Asia/Bangkok',
    latitude: 13.76,
    longitude: 100.50,
  ),
  City('Hanoi', 'Vietnam', 'Asia/Bangkok', latitude: 21.03, longitude: 105.85),
  City(
    'Ho Chi Minh City',
    'Vietnam',
    'Asia/Ho_Chi_Minh',
    latitude: 10.82,
    longitude: 106.63,
  ),
  City(
    'Jakarta',
    'Indonesia',
    'Asia/Jakarta',
    latitude: -6.21,
    longitude: 106.85,
  ),
  City(
    'Kuala Lumpur',
    'Malaysia',
    'Asia/Kuala_Lumpur',
    latitude: 3.14,
    longitude: 101.69,
  ),
  City(
    'Singapore',
    'Singapore',
    'Asia/Singapore',
    latitude: 1.35,
    longitude: 103.82,
  ),
  City(
    'Hong Kong',
    'China',
    'Asia/Hong_Kong',
    latitude: 22.32,
    longitude: 114.17,
  ),
  City('Beijing', 'China', 'Asia/Shanghai', latitude: 39.90, longitude: 116.41),
  City(
    'Shanghai',
    'China',
    'Asia/Shanghai',
    latitude: 31.23,
    longitude: 121.47,
  ),
  City('Taipei', 'Taiwan', 'Asia/Taipei', latitude: 25.03, longitude: 121.57),
  City(
    'Manila',
    'Philippines',
    'Asia/Manila',
    latitude: 14.60,
    longitude: 120.98,
  ),
  City(
    'Perth',
    'Australia',
    'Australia/Perth',
    latitude: -31.95,
    longitude: 115.86,
  ),
  City(
    'Seoul',
    'South Korea',
    'Asia/Seoul',
    latitude: 37.57,
    longitude: 126.98,
  ),
  City('Tokyo', 'Japan', 'Asia/Tokyo', latitude: 35.68, longitude: 139.69),
  City('Osaka', 'Japan', 'Asia/Tokyo', latitude: 34.69, longitude: 135.50),
  City(
    'Darwin',
    'Australia',
    'Australia/Darwin',
    latitude: -12.46,
    longitude: 130.84,
  ),
  City(
    'Adelaide',
    'Australia',
    'Australia/Adelaide',
    latitude: -34.93,
    longitude: 138.60,
  ),
  City(
    'Brisbane',
    'Australia',
    'Australia/Brisbane',
    latitude: -27.47,
    longitude: 153.03,
  ),
  City(
    'Sydney',
    'Australia',
    'Australia/Sydney',
    latitude: -33.87,
    longitude: 151.21,
  ),
  City(
    'Melbourne',
    'Australia',
    'Australia/Melbourne',
    latitude: -37.81,
    longitude: 144.96,
  ),
  City('Guam', 'USA', 'Pacific/Guam', latitude: 13.44, longitude: 144.79),
  City(
    'Nouméa',
    'New Caledonia',
    'Pacific/Noumea',
    latitude: -22.27,
    longitude: 166.44,
  ),
  City(
    'Auckland',
    'New Zealand',
    'Pacific/Auckland',
    latitude: -36.85,
    longitude: 174.76,
  ),
  City('Fiji', 'Fiji', 'Pacific/Fiji', latitude: -18.12, longitude: 178.45),
  City(
    'Tonga',
    'Tonga',
    'Pacific/Tongatapu',
    latitude: -21.14,
    longitude: -175.20,
  ),
  City(
    'Kiritimati',
    'Kiribati',
    'Pacific/Kiritimati',
    latitude: 1.87,
    longitude: -157.43,
  ),
];

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áàâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôöõ]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ã', 'a');

List<City> searchCities(String query) {
  final q = _fold(query.trim());
  return [
    for (final c in worldCities)
      if (_fold(c.name).contains(q) || _fold(c.country).contains(q)) c,
  ];
}

City? cityForZone(String zone) {
  for (final c in worldCities) {
    if (c.zone == zone) return c;
  }
  return null;
}

class CityTime {
  const CityTime(this.time, this.dayLabel, this.difference);

  final String time;
  final String dayLabel;
  final String difference;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// The time in a city at UTC offset [offset], for someone whose own offset
/// is [localOffset].
CityTime cityTime(DateTime nowUtc, Duration offset, Duration localOffset) {
  final there = nowUtc.toUtc().add(offset);
  final here = nowUtc.toUtc().add(localOffset);
  final dayDiff = DateTime.utc(
    there.year,
    there.month,
    there.day,
  ).difference(DateTime.utc(here.year, here.month, here.day)).inDays;
  final label = switch (dayDiff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => dayDiff > 0 ? 'In $dayDiff days' : '${-dayDiff} days ago',
  };
  final diff = offset - localOffset;
  final mins = diff.inMinutes.abs();
  final h = mins ~/ 60, m = mins % 60;
  final amount = m == 0 ? '$h h' : (h == 0 ? '$m min' : '$h h $m min');
  final difference = diff == Duration.zero
      ? 'Same time'
      : '${diff.isNegative ? '−' : '+'}$amount';
  return CityTime(
    '${_two(there.hour)}:${_two(there.minute)}',
    label,
    difference,
  );
}

/// UTC offsets of time zones right now, from the phone's own zone database
/// (so summer time is right).
abstract class ZoneOffsets {
  Future<Map<String, Duration>> offsets(List<String> zones, DateTime at);
}

class MethodChannelZoneOffsets implements ZoneOffsets {
  static const _channel = MethodChannel('byebyesleep/zones');

  @override
  Future<Map<String, Duration>> offsets(List<String> zones, DateTime at) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('offsets', {
        'zones': zones,
        'atMs': at.millisecondsSinceEpoch,
      });
      return {
        for (final MapEntry(:key, :value) in (raw ?? const {}).entries)
          if (value is num) key: Duration(seconds: value.toInt()),
      };
    } on MissingPluginException {
      return const {};
    }
  }
}

final zoneOffsetsProvider = Provider<ZoneOffsets>(
  (_) => MethodChannelZoneOffsets(),
);

abstract class WorldClockStore {
  Future<List<City>> load();
  Future<void> save(List<City> cities);
}

/// `world_clocks.json` in the documents folder.
class FileWorldClockStore implements WorldClockStore {
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/world_clocks.json',
  );

  @override
  Future<List<City>> load() async {
    try {
      return [
        for (final saved
            in jsonDecode(await (await _file).readAsString()) as List)
          ?City.fromSaved(saved),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<City> cities) async => (await _file).writeAsString(
    jsonEncode([for (final c in cities) c.toJson()]),
  );
}

final worldClockStoreProvider = Provider<WorldClockStore>(
  (_) => FileWorldClockStore(),
);

class WorldClocksNotifier extends AsyncNotifier<List<City>> {
  @override
  Future<List<City>> build() => ref.read(worldClockStoreProvider).load();

  Future<void> _set(List<City> cities) async {
    state = AsyncData(cities);
    await ref.read(worldClockStoreProvider).save(cities);
  }

  List<City> get _cities => state.value ?? const [];

  Future<void> add(City city) async {
    if (_cities.every((c) => c.id != city.id)) await _set([..._cities, city]);
  }

  Future<void> remove(City city) async => _set([
    for (final c in _cities)
      if (c.id != city.id) c,
  ]);
}

final worldClocksProvider =
    AsyncNotifierProvider<WorldClocksNotifier, List<City>>(
      WorldClocksNotifier.new,
    );

// ---------------------------------------------------------------------------
// Online: city search and weather from Open-Meteo (free, no account, no key).

/// GETs a URL and returns the body; tests pass a fake.
typedef HttpGet = Future<String> Function(Uri url);

Future<String> _httpGet(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final request = await client.getUrl(url);
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}', uri: url);
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

final httpGetProvider = Provider<HttpGet>((_) => _httpGet);

/// Cities from an Open-Meteo geocoding answer; results without a time zone
/// are left out (no clock without one).
List<City> parseGeocoding(String body) {
  final results = (jsonDecode(body) as Map)['results'] as List? ?? const [];
  return [
    for (final r in results.cast<Map<Object?, Object?>>())
      if (r['timezone'] is String && r['name'] is String)
        City(
          r['name']! as String,
          r['country'] as String? ?? '',
          r['timezone']! as String,
          latitude: (r['latitude'] as num?)?.toDouble(),
          longitude: (r['longitude'] as num?)?.toDouble(),
          region: [
            if (r['admin1'] case final String a when a.isNotEmpty) a,
            if (r['country'] case final String c when c.isNotEmpty) c,
          ].join(', '),
        ),
  ];
}

/// Any city in the world, by name (Open-Meteo geocoding).
Future<List<City>> searchCitiesOnline(HttpGet get, String query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final body = await get(
    Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '20',
      'language': 'en',
      'format': 'json',
    }),
  );
  return parseGeocoding(body);
}

class Weather {
  const Weather({
    required this.temperatureC,
    required this.code,
    this.isDay = true,
  });

  final double temperatureC;

  /// WMO weather code.
  final int code;
  final bool isDay;

  String get description => weatherDescription(code);

  String temperatureText({required bool fahrenheit}) =>
      '${(fahrenheit ? temperatureC * 9 / 5 + 32 : temperatureC).round()}°';
}

Weather? parseWeather(String body) {
  final current = (jsonDecode(body) as Map)['current'];
  if (current is! Map) return null;
  final t = current['temperature_2m'];
  final code = current['weather_code'];
  if (t is! num || code is! num) return null;
  return Weather(
    temperatureC: t.toDouble(),
    code: code.toInt(),
    isDay: current['is_day'] != 0,
  );
}

/// Words for the WMO weather codes Open-Meteo uses.
String weatherDescription(int code) => switch (code) {
  0 => 'Clear',
  1 || 2 => 'Partly cloudy',
  3 => 'Cloudy',
  45 || 48 => 'Fog',
  >= 51 && <= 57 => 'Drizzle',
  >= 61 && <= 67 || >= 80 && <= 82 => 'Rain',
  >= 71 && <= 77 || 85 || 86 => 'Snow',
  >= 95 => 'Thunderstorm',
  _ => 'Unknown',
};

/// Current weather at a place, cached for 30 minutes.
class WeatherSource {
  WeatherSource(this._get, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final HttpGet _get;
  final DateTime Function() _now;
  final _cache = <String, (DateTime, Weather?)>{};

  Future<Weather?> current(double lat, double lon) async {
    final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    final hit = _cache[key];
    if (hit != null &&
        _now().difference(hit.$1) < const Duration(minutes: 30)) {
      return hit.$2;
    }
    Weather? w;
    try {
      w = parseWeather(
        await _get(
          Uri.https('api.open-meteo.com', '/v1/forecast', {
            'latitude': '$lat',
            'longitude': '$lon',
            'current': 'temperature_2m,weather_code,is_day',
          }),
        ),
      );
    } catch (_) {
      w = null; // offline: no weather, the clock still works
    }
    _cache[key] = (_now(), w);
    return w;
  }
}

final weatherSourceProvider = Provider<WeatherSource>(
  (ref) => WeatherSource(ref.read(httpGetProvider)),
);
