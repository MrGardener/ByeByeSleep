import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../alarm/guard.dart';
import 'name_dialog.dart';
import 'stopwatch_state.dart';

class StopwatchEntry {
  const StopwatchEntry({
    required this.id,
    required this.name,
    this.state = const StopwatchState(),
  });

  final int id;
  final String name;
  final StopwatchState state;

  StopwatchEntry copyWith({String? name, StopwatchState? state}) =>
      StopwatchEntry(
        id: id,
        name: name ?? this.name,
        state: state ?? this.state,
      );
}

class StopwatchesState {
  const StopwatchesState({
    this.watches = const [StopwatchEntry(id: 1, name: 'Stopwatch 1')],
    this.nextId = 2,
  });

  factory StopwatchesState.fromJson(Map<String, Object?> j) => StopwatchesState(
    watches: [
      for (final w in (j['watches'] as List? ?? const []))
        StopwatchEntry(
          id: ((w as Map)['id']! as num).toInt(),
          name: w['name'] as String? ?? 'Stopwatch',
          state: StopwatchState.fromJson(
            (w['state'] as Map? ?? const {}).cast<String, Object?>(),
          ),
        ),
    ],
    nextId: (j['nextId'] as num?)?.toInt() ?? 1,
  );

  final List<StopwatchEntry> watches;
  final int nextId;

  Map<String, Object?> toJson() => {
    'watches': [
      for (final w in watches)
        {'id': w.id, 'name': w.name, 'state': w.state.toJson()},
    ],
    'nextId': nextId,
  };
}

abstract class StopwatchStore {
  Future<StopwatchesState?> load();
  Future<void> save(StopwatchesState state);
}

/// `stopwatches.json` in the documents folder: running stopwatches keep
/// counting while the app is closed.
class FileStopwatchStore implements StopwatchStore {
  Future<File> get _file async => File(
    '${(await getApplicationDocumentsDirectory()).path}/stopwatches.json',
  );

  @override
  Future<StopwatchesState?> load() async {
    try {
      final j = jsonDecode(await (await _file).readAsString());
      return StopwatchesState.fromJson((j as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(StopwatchesState state) async =>
      (await _file).writeAsString(jsonEncode(state.toJson()));
}

final stopwatchStoreProvider = Provider<StopwatchStore>(
  (_) => FileStopwatchStore(),
);

class StopwatchesNotifier extends AsyncNotifier<StopwatchesState> {
  DateTime _now() => ref.read(nowProvider)();
  StopwatchesState get _s => state.value ?? const StopwatchesState();

  @override
  Future<StopwatchesState> build() async =>
      await ref.read(stopwatchStoreProvider).load() ?? const StopwatchesState();

  Future<void> _set(StopwatchesState next) async {
    state = AsyncData(next);
    await ref.read(stopwatchStoreProvider).save(next);
  }

  Future<void> _update(int id, StopwatchEntry Function(StopwatchEntry) f) =>
      _set(
        StopwatchesState(
          watches: [for (final w in _s.watches) w.id == id ? f(w) : w],
          nextId: _s.nextId,
        ),
      );

  Future<void> add() => _set(
    StopwatchesState(
      watches: [
        ..._s.watches,
        StopwatchEntry(id: _s.nextId, name: 'Stopwatch ${_s.nextId}'),
      ],
      nextId: _s.nextId + 1,
    ),
  );

  Future<void> remove(int id) => _set(
    StopwatchesState(
      watches: [
        for (final w in _s.watches)
          if (w.id != id) w,
      ],
      nextId: _s.nextId,
    ),
  );

  Future<void> startOrPause(int id) => _update(
    id,
    (w) => w.copyWith(
      state: w.state.running ? w.state.pause(_now()) : w.state.start(_now()),
    ),
  );

  Future<void> lap(int id) =>
      _update(id, (w) => w.copyWith(state: w.state.lap(_now())));

  Future<void> reset(int id) =>
      _update(id, (w) => w.copyWith(state: w.state.reset()));

  Future<void> rename(int id, String name) =>
      _update(id, (w) => w.copyWith(name: name));
}

final stopwatchesProvider =
    AsyncNotifierProvider<StopwatchesNotifier, StopwatchesState>(
      StopwatchesNotifier.new,
    );

/// Height of a stopwatch with lap and reset; the ones that fit on the
/// screen get them, the others only start/pause.
const _fullHeight = 176.0;
const _headerHeight = 72.0;

class StopwatchScreen extends ConsumerStatefulWidget {
  const StopwatchScreen({super.key});

  @override
  ConsumerState<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends ConsumerState<StopwatchScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final watches = ref.read(stopwatchesProvider).value?.watches ?? const [];
      if (watches.any((w) => w.state.running)) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _rename(StopwatchEntry w) async {
    final name = await askName(
      context,
      title: 'Name this stopwatch',
      initial: w.name,
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(stopwatchesProvider.notifier).rename(w.id, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stopwatchesProvider).value;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final notifier = ref.read(stopwatchesProvider.notifier);
    final now = ref.read(nowProvider)();
    return LayoutBuilder(
      builder: (context, box) {
        final fullSlots = ((box.maxHeight - _headerHeight) / _fullHeight)
            .floor()
            .clamp(1, 1 << 20);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            SizedBox(
              height: _headerHeight - 16,
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: const Key('sw-add'),
                  onPressed: notifier.add,
                  icon: const Icon(Icons.add),
                  label: const Text('Add stopwatch'),
                ),
              ),
            ),
            for (final (i, w) in s.watches.indexed)
              _StopwatchCard(
                watch: w,
                now: now,
                full: i < fullSlots,
                notifier: notifier,
                onRename: () => _rename(w),
              ),
          ],
        );
      },
    );
  }
}

class _StopwatchCard extends StatelessWidget {
  const _StopwatchCard({
    required this.watch,
    required this.now,
    required this.full,
    required this.notifier,
    required this.onRename,
  });

  final StopwatchEntry watch;
  final DateTime now;
  final bool full;
  final StopwatchesNotifier notifier;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final sw = watch.state;
    final id = watch.id;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final started = sw.running || sw.elapsed(now) > Duration.zero;
    final time = Text(
      formatStopwatch(sw.elapsed(now)),
      style: (full ? text.displaySmall : text.headlineSmall)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final startButton = IconButton.filled(
      key: Key('sw-$id-start'),
      tooltip: sw.running ? 'Pause' : (started ? 'Resume' : 'Start'),
      onPressed: () => notifier.startOrPause(id),
      icon: Icon(sw.running ? Icons.pause_rounded : Icons.play_arrow_rounded),
    );
    final name = InkWell(
      key: Key('sw-$id-name'),
      onTap: onRename,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                watch.name,
                style: text.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 14, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
    return Dismissible(
      key: Key('sw-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => notifier.remove(id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: scheme.error),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: !full
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [name, time],
                      ),
                    ),
                    startButton,
                  ],
                )
              : SizedBox(
                  height: _fullHeight - 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      time,
                      Text(
                        sw.laps.isEmpty
                            ? ' '
                            : sw.laps
                                  .take(2)
                                  .map(
                                    (l) =>
                                        'Lap ${l.number} +${formatStopwatch(l.split)}',
                                  )
                                  .join('   '),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            key: Key('sw-$id-reset'),
                            onPressed: !started || sw.running
                                ? null
                                : () => notifier.reset(id),
                            child: const Text('Reset'),
                          ),
                          TextButton(
                            key: Key('sw-$id-lap'),
                            onPressed: sw.running
                                ? () => notifier.lap(id)
                                : null,
                            child: const Text('Lap'),
                          ),
                          const SizedBox(width: 8),
                          startButton,
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
