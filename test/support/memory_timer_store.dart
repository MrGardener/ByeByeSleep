import 'package:byebyesleep/tools/timer_bell.dart';

class MemoryTimerStore implements TimerStore {
  TimersState? saved;

  @override
  Future<TimersState?> load() async => saved;

  @override
  Future<void> save(TimersState state) async => saved = state;
}
