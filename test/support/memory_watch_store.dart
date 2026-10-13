import 'package:byebyesleep/watch_setup/watch_settings.dart';

/// Watch settings kept in memory (the real store reads a file).
class MemoryWatchStore implements WatchSettingsStore {
  MemoryWatchStore([this.saved = const WatchSettings()]);

  WatchSettings saved;

  @override
  Future<WatchSettings> load() async => saved;

  @override
  Future<void> save(WatchSettings s) async => saved = s;
}
