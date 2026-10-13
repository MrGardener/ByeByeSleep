import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../challenges/core/types.dart';

/// Sensors that come from the watch.
const watchKinds = {
  SensorKind.heartRate,
  SensorKind.watchMotion,
  SensorKind.watchSteps,
};

/// Whether the owner uses a watch with the app.
enum WatchChoice {
  /// Not asked yet: watch challenges are not offered.
  unknown,

  /// "No watch": watch features are hidden.
  none,

  /// Set up and tested: the sensors that answered can be used.
  verified,
}

class WatchSettings {
  const WatchSettings({
    this.choice = WatchChoice.unknown,
    this.sensors = const {},
  });

  final WatchChoice choice;

  /// Watch sensors that sent readings during the setup test.
  final Set<SensorKind> sensors;

  bool get ready => choice == WatchChoice.verified && sensors.isNotEmpty;

  Map<String, Object?> toJson() => {
    'choice': choice.name,
    'sensors': [for (final s in sensors) s.name],
  };

  factory WatchSettings.fromJson(Map<String, Object?> j) => WatchSettings(
    choice: WatchChoice.values.asNameMap()[j['choice']] ?? WatchChoice.unknown,
    sensors: {
      for (final n in (j['sensors'] as List?) ?? const [])
        if (SensorKind.values.asNameMap()[n] case final k?)
          if (watchKinds.contains(k)) k,
    },
  );
}

abstract class WatchSettingsStore {
  Future<WatchSettings> load();
  Future<void> save(WatchSettings settings);
}

/// `watch.json` in the documents folder; missing or unreadable = not asked.
class FileWatchSettingsStore implements WatchSettingsStore {
  FileWatchSettingsStore(this._dir);

  final Future<Directory> Function() _dir;

  Future<File> get _file async => File('${(await _dir()).path}/watch.json');

  @override
  Future<WatchSettings> load() async {
    try {
      final json = jsonDecode(await (await _file).readAsString());
      return WatchSettings.fromJson((json as Map).cast<String, Object?>());
    } catch (_) {
      return const WatchSettings();
    }
  }

  @override
  Future<void> save(WatchSettings settings) async {
    final file = await _file;
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(settings.toJson()));
    await tmp.rename(file.path);
  }
}

final watchSettingsStoreProvider = Provider<WatchSettingsStore>(
  (_) => FileWatchSettingsStore(getApplicationDocumentsDirectory),
);

class WatchSettingsNotifier extends AsyncNotifier<WatchSettings> {
  @override
  Future<WatchSettings> build() => ref.read(watchSettingsStoreProvider).load();

  Future<void> set(WatchSettings settings) async {
    state = AsyncData(settings);
    await ref.read(watchSettingsStoreProvider).save(settings);
  }
}

final watchSettingsProvider =
    AsyncNotifierProvider<WatchSettingsNotifier, WatchSettings>(
      WatchSettingsNotifier.new,
    );
