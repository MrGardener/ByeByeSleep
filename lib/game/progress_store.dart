import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'quest.dart';

/// Which Sensor Quest worlds the player has completed.
abstract class ProgressStore {
  Future<Set<World>> load();
  Future<void> save(Set<World> completed);
}

/// `quest.json` in a directory: `{"completed": ["batteryOracle", …]}`.
/// A missing or unreadable file means a fresh start.
class FileProgressStore implements ProgressStore {
  FileProgressStore(this._dir);

  final Future<Directory> Function() _dir;

  Future<File> get _file async => File('${(await _dir()).path}/quest.json');

  @override
  Future<Set<World>> load() async {
    try {
      final json = jsonDecode(await (await _file).readAsString());
      final names = (json as Map<String, Object?>)['completed']! as List;
      return {
        for (final w in World.values)
          if (names.contains(w.name)) w,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> save(Set<World> completed) async {
    await (await _file).writeAsString(
      jsonEncode({
        'completed': [for (final w in completed) w.name],
      }),
    );
  }
}

final progressStoreProvider = Provider<ProgressStore>(
  (_) => FileProgressStore(getApplicationDocumentsDirectory),
);

class QuestProgress extends AsyncNotifier<Set<World>> {
  @override
  Future<Set<World>> build() => ref.read(progressStoreProvider).load();

  Future<void> complete(World w) async {
    final done = {...await future, w};
    state = AsyncData(done);
    await ref.read(progressStoreProvider).save(done);
  }
}

final questProgressProvider = AsyncNotifierProvider<QuestProgress, Set<World>>(
  QuestProgress.new,
);
