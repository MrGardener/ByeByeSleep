import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'world_clock.dart';

enum ClockFace { digital, analog }

enum TimeFormat { system, h24, h12 }

/// How clocks look, and which time zone is home.
class ClockPrefs {
  const ClockPrefs({
    this.face = ClockFace.digital,
    this.hours = TimeFormat.system,
    this.showSeconds = true,
    this.home,
    this.homeClockWhenAway = true,
  });

  factory ClockPrefs.fromJson(Map<String, Object?> j) => ClockPrefs(
    face: ClockFace.values.asNameMap()[j['face']] ?? ClockFace.digital,
    hours: TimeFormat.values.asNameMap()[j['hours']] ?? TimeFormat.system,
    showSeconds: j['seconds'] != false,
    home: City.fromSaved(j['home']),
    homeClockWhenAway: j['homeClock'] != false,
  );

  final ClockFace face;
  final TimeFormat hours;
  final bool showSeconds;

  /// Your main time zone; when the phone is in another one (travelling),
  /// the clock shows home time too. Null: the phone's zone is home.
  final City? home;
  final bool homeClockWhenAway;

  Map<String, Object?> toJson() => {
    'face': face.name,
    'hours': hours.name,
    'seconds': showSeconds,
    'home': ?home?.toJson(),
    'homeClock': homeClockWhenAway,
  };

  ClockPrefs copyWith({
    ClockFace? face,
    TimeFormat? hours,
    bool? showSeconds,
    City? Function()? home,
    bool? homeClockWhenAway,
  }) => ClockPrefs(
    face: face ?? this.face,
    hours: hours ?? this.hours,
    showSeconds: showSeconds ?? this.showSeconds,
    home: home != null ? home() : this.home,
    homeClockWhenAway: homeClockWhenAway ?? this.homeClockWhenAway,
  );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "06:30" or "6:30 AM". [use24] comes from the setting, or from the
/// phone's own choice when the setting is "system".
String formatHm(int hour, int minute, {required bool use24}) {
  if (use24) return '${_two(hour)}:${_two(minute)}';
  final h = hour % 12 == 0 ? 12 : hour % 12;
  return '$h:${_two(minute)} ${hour < 12 ? 'AM' : 'PM'}';
}

bool uses24(TimeFormat f, {required bool systemUses24}) => switch (f) {
  TimeFormat.system => systemUses24,
  TimeFormat.h24 => true,
  TimeFormat.h12 => false,
};

abstract class ClockPrefsStore {
  Future<ClockPrefs> load();
  Future<void> save(ClockPrefs prefs);
}

/// `clock_prefs.json` in the documents folder.
class FileClockPrefsStore implements ClockPrefsStore {
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/clock_prefs.json',
  );

  @override
  Future<ClockPrefs> load() async {
    try {
      final j = jsonDecode(await (await _file).readAsString());
      return ClockPrefs.fromJson((j as Map).cast<String, Object?>());
    } catch (_) {
      return const ClockPrefs();
    }
  }

  @override
  Future<void> save(ClockPrefs prefs) async =>
      (await _file).writeAsString(jsonEncode(prefs.toJson()));
}

class MemoryClockPrefsStore implements ClockPrefsStore {
  ClockPrefs saved = const ClockPrefs();

  @override
  Future<ClockPrefs> load() async => saved;

  @override
  Future<void> save(ClockPrefs prefs) async => saved = prefs;
}

final clockPrefsStoreProvider = Provider<ClockPrefsStore>(
  (_) => FileClockPrefsStore(),
);

class ClockPrefsNotifier extends AsyncNotifier<ClockPrefs> {
  @override
  Future<ClockPrefs> build() => ref.read(clockPrefsStoreProvider).load();

  Future<void> set(ClockPrefs prefs) async {
    state = AsyncData(prefs);
    await ref.read(clockPrefsStoreProvider).save(prefs);
  }

  Future<void> change(ClockPrefs Function(ClockPrefs) f) =>
      set(f(state.value ?? const ClockPrefs()));
}

final clockPrefsProvider =
    AsyncNotifierProvider<ClockPrefsNotifier, ClockPrefs>(
      ClockPrefsNotifier.new,
    );
