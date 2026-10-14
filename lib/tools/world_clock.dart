import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

class City {
  const City(this.name, this.country, this.zone);

  final String name;
  final String country;

  /// IANA time zone, e.g. Europe/Paris.
  final String zone;
}

const worldCities = [
  City('Honolulu', 'USA', 'Pacific/Honolulu'),
  City('Anchorage', 'USA', 'America/Anchorage'),
  City('Los Angeles', 'USA', 'America/Los_Angeles'),
  City('Vancouver', 'Canada', 'America/Vancouver'),
  City('Denver', 'USA', 'America/Denver'),
  City('Mexico City', 'Mexico', 'America/Mexico_City'),
  City('Chicago', 'USA', 'America/Chicago'),
  City('New York', 'USA', 'America/New_York'),
  City('Toronto', 'Canada', 'America/Toronto'),
  City('Bogotá', 'Colombia', 'America/Bogota'),
  City('Lima', 'Peru', 'America/Lima'),
  City('Caracas', 'Venezuela', 'America/Caracas'),
  City('Santiago', 'Chile', 'America/Santiago'),
  City('Buenos Aires', 'Argentina', 'America/Argentina/Buenos_Aires'),
  City('São Paulo', 'Brazil', 'America/Sao_Paulo'),
  City('Reykjavík', 'Iceland', 'Atlantic/Reykjavik'),
  City('London', 'UK', 'Europe/London'),
  City('Lisbon', 'Portugal', 'Europe/Lisbon'),
  City('Madrid', 'Spain', 'Europe/Madrid'),
  City('Paris', 'France', 'Europe/Paris'),
  City('Amsterdam', 'Netherlands', 'Europe/Amsterdam'),
  City('Berlin', 'Germany', 'Europe/Berlin'),
  City('Rome', 'Italy', 'Europe/Rome'),
  City('Stockholm', 'Sweden', 'Europe/Stockholm'),
  City('Athens', 'Greece', 'Europe/Athens'),
  City('Istanbul', 'Türkiye', 'Europe/Istanbul'),
  City('Cairo', 'Egypt', 'Africa/Cairo'),
  City('Lagos', 'Nigeria', 'Africa/Lagos'),
  City('Johannesburg', 'South Africa', 'Africa/Johannesburg'),
  City('Nairobi', 'Kenya', 'Africa/Nairobi'),
  City('Moscow', 'Russia', 'Europe/Moscow'),
  City('Dubai', 'UAE', 'Asia/Dubai'),
  City('Karachi', 'Pakistan', 'Asia/Karachi'),
  City('Delhi', 'India', 'Asia/Kolkata'),
  City('Kathmandu', 'Nepal', 'Asia/Kathmandu'),
  City('Dhaka', 'Bangladesh', 'Asia/Dhaka'),
  City('Bangkok', 'Thailand', 'Asia/Bangkok'),
  City('Jakarta', 'Indonesia', 'Asia/Jakarta'),
  City('Singapore', 'Singapore', 'Asia/Singapore'),
  City('Hong Kong', 'China', 'Asia/Hong_Kong'),
  City('Shanghai', 'China', 'Asia/Shanghai'),
  City('Manila', 'Philippines', 'Asia/Manila'),
  City('Seoul', 'South Korea', 'Asia/Seoul'),
  City('Tokyo', 'Japan', 'Asia/Tokyo'),
  City('Perth', 'Australia', 'Australia/Perth'),
  City('Sydney', 'Australia', 'Australia/Sydney'),
  City('Auckland', 'New Zealand', 'Pacific/Auckland'),
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
  Future<List<String>> load();
  Future<void> save(List<String> zones);
}

/// `world_clocks.json` in the documents folder.
class FileWorldClockStore implements WorldClockStore {
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/world_clocks.json',
  );

  @override
  Future<List<String>> load() async {
    try {
      return [
        for (final z in jsonDecode(await (await _file).readAsString()) as List)
          z as String,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> save(List<String> zones) async =>
      (await _file).writeAsString(jsonEncode(zones));
}

final worldClockStoreProvider = Provider<WorldClockStore>(
  (_) => FileWorldClockStore(),
);

class WorldClocksNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() => ref.read(worldClockStoreProvider).load();

  Future<void> _set(List<String> zones) async {
    state = AsyncData(zones);
    await ref.read(worldClockStoreProvider).save(zones);
  }

  List<String> get _zones => state.value ?? const [];

  Future<void> add(String zone) async {
    if (!_zones.contains(zone)) await _set([..._zones, zone]);
  }

  Future<void> remove(String zone) async => _set([..._zones]..remove(zone));
}

final worldClocksProvider =
    AsyncNotifierProvider<WorldClocksNotifier, List<String>>(
      WorldClocksNotifier.new,
    );
