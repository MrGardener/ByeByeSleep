/// Odd one out: a grid of the same symbol, one turned slightly; find it
/// three times in a row. Pure Dart.
library;

import 'dart:math';

class OddRound {
  const OddRound(this.odd, this.glyph);

  /// Cell index (row by row) of the different symbol.
  final int odd;

  /// Which symbol this round uses, 0 until [OddOneOut.glyphCount].
  final int glyph;
}

class OddOneOut {
  OddOneOut(int difficulty, this.random, {this.fixedOdd})
    : _d = difficulty.clamp(1, 5) - 1 {
    round = _newRound();
  }

  static const rounds = 3;

  /// Symbols the screen can draw (it maps each to an icon).
  static const glyphCount = 6;

  final Random random;

  /// Tests: the odd one is always in this cell.
  final int? fixedOdd;
  final int _d;

  late OddRound round;
  int streak = 0;

  /// 3×3 at difficulty 1 … 6×6 at 5.
  int get size => const [3, 4, 4, 5, 6][_d];

  /// How far the odd one is turned: half a turn at 1 … 15° at 5.
  double get angleDegrees => const [180.0, 90.0, 45.0, 25.0, 15.0][_d];

  bool get passed => streak >= rounds;

  OddRound _newRound() => OddRound(
    fixedOdd ?? random.nextInt(size * size),
    random.nextInt(glyphCount),
  );

  /// Right: one more in the streak. Wrong: the streak starts again. Either
  /// way a new grid follows.
  bool tap(int cell) {
    if (passed) return true;
    final right = cell == round.odd;
    streak = right ? streak + 1 : 0;
    if (!passed) round = _newRound();
    return right;
  }
}
