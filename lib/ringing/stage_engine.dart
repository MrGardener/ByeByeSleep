import '../alarm/stage_config.dart';
import '../challenges/core/challenge_id.dart';

const hintAfter = Duration(minutes: 2);
const fallbackAfter = Duration(minutes: 5);
const safetyExitAfter = Duration(minutes: 15);
const breatherLevel = 0.2;

sealed class StagePhase {
  const StagePhase();
}

class Running extends StagePhase {
  const Running({
    required this.index,
    required this.stage,
    required this.hintVisible,
    required this.fallbackAvailable,
  });

  final int index;
  final StageConfig stage;
  final bool hintVisible;
  final bool fallbackAvailable;
}

class Breather extends StagePhase {
  const Breather({required this.nextIndex, required this.remaining});

  final int nextIndex;
  final Duration remaining;
}

class Done extends StagePhase {
  const Done();
}

/// Walks a ringing alarm through its stages: each stage runs until passed,
/// then a quieter breather leads into the next one. Pure; time comes from
/// [clock] so tests control it.
class StageEngine {
  StageEngine({
    required List<StageConfig> stages,
    required this.ringStartedAt,
    int startIndex = 0,
    required this.clock,
    this.breather = const Duration(seconds: 20),
  }) : _stages = [...stages],
       _index = startIndex.clamp(0, stages.length) {
    _stageStartedAt = clock();
  }

  final DateTime ringStartedAt;
  final Duration breather;
  final List<StageConfig> _stages;
  final DateTime Function() clock;
  int _index;
  late DateTime _stageStartedAt;
  DateTime? _breatherEndsAt;

  /// Index of the stage being run (or next to run); equals the stage count
  /// once every stage is passed.
  int get currentIndex => _breatherEndsAt == null ? _index : _index + 1;

  bool get _done => _index >= _stages.length;

  StagePhase get phase {
    if (_done) return const Done();
    final now = clock();
    final breatherEnd = _breatherEndsAt;
    if (breatherEnd != null) {
      final left = breatherEnd.difference(now);
      return Breather(
        nextIndex: _index + 1,
        remaining: left.isNegative ? Duration.zero : left,
      );
    }
    final onStage = now.difference(_stageStartedAt);
    return Running(
      index: _index,
      stage: _stages[_index],
      hintVisible: onStage >= hintAfter,
      fallbackAvailable: onStage >= fallbackAfter,
    );
  }

  bool get safetyExitAvailable =>
      clock().difference(ringStartedAt) >= safetyExitAfter;

  double get ringLevel => phase is Breather ? breatherLevel : 1.0;

  void stagePassed() {
    if (_done || _breatherEndsAt != null) return;
    if (_index == _stages.length - 1) {
      _index = _stages.length;
    } else {
      _breatherEndsAt = clock().add(breather);
    }
  }

  /// Swaps the current stage for [replacement] at the same difficulty and
  /// restarts its timer.
  void useFallback(ChallengeId replacement) {
    if (phase is! Running) return;
    _stages[_index] = _stages[_index].copyWith(challenge: replacement);
    _stageStartedAt = clock();
  }

  void tick() {
    final end = _breatherEndsAt;
    if (end != null && !clock().isBefore(end)) {
      _breatherEndsAt = null;
      _index++;
      _stageStartedAt = clock();
    }
  }
}
