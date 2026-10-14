import 'package:byebyesleep/tools/timer_bell.dart';
import 'package:byebyesleep/tools/timer_state.dart';

class MemoryTimerStore implements TimerStore {
  TimerState? saved;

  @override
  Future<TimerState?> load() async => saved;

  @override
  Future<void> save(TimerState state) async => saved = state;
}
