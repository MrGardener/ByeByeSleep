import 'dart:math';

import '../core/types.dart';

enum InkColor { red, green, blue, yellow, purple }

/// Colour words printed in a different ink: tap the ink, not the word.
class StroopDetector {
  StroopDetector({required this.difficulty, required this.random})
    : required = difficulty.clamp(1, 5) + 2,
      _palette = difficulty >= 4
          ? InkColor.values
          : InkColor.values.sublist(0, 4) {
    _choices = [..._palette];
    _nextRound();
  }

  final int difficulty;
  final Random random;

  /// Correct answers in a row needed to pass.
  final int required;
  final List<InkColor> _palette;
  late List<InkColor> _choices;
  late String _word;
  late InkColor _ink;
  int _streak = 0;

  String get word => _word;
  InkColor get ink => _ink;
  List<InkColor> get choices => List.unmodifiable(_choices);
  ChallengeProgress get progress => _streak >= required
      ? ChallengeProgress.complete
      : ChallengeProgress(_streak / required);

  ChallengeProgress choose(InkColor c) {
    if (progress.passed) return progress;
    _streak = c == _ink ? _streak + 1 : 0;
    if (!progress.passed) _nextRound();
    return progress;
  }

  void _nextRound() {
    _ink = _palette[random.nextInt(_palette.length)];
    final words = _palette.where((c) => c != _ink).toList();
    _word = words[random.nextInt(words.length)].name.toUpperCase();
    if (difficulty >= 3) _choices.shuffle(random);
  }
}
