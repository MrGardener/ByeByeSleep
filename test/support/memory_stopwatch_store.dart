import 'package:byebyesleep/tools/stopwatch_screen.dart';

class MemoryStopwatchStore implements StopwatchStore {
  StopwatchesState? saved;

  @override
  Future<StopwatchesState?> load() async => saved;

  @override
  Future<void> save(StopwatchesState state) async => saved = state;
}
