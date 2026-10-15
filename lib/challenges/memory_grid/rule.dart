/// Memory grid: some tiles light up; tap the same tiles back. Pure Dart.
library;

import 'dart:math';

enum GridState { going, right, wrong }

class MemoryPattern {
  const MemoryPattern(this.size, this.lit);

  /// 3 of 3×3 tiles at difficulty 1 … 8 of 5×5 at 5. [tiles] fixes the lit
  /// tiles (tests).
  factory MemoryPattern.forDifficulty(
    int difficulty,
    Random random, {
    List<int>? tiles,
  }) {
    final d = difficulty.clamp(1, 5) - 1;
    final size = const [3, 4, 4, 5, 5][d];
    if (tiles != null) return MemoryPattern(size, tiles.toSet());
    final cells = List.generate(size * size, (i) => i)..shuffle(random);
    return MemoryPattern(size, cells.take(const [3, 4, 5, 6, 8][d]).toSet());
  }

  /// Tiles per side.
  final int size;

  /// Lit tile indices, row by row from the top left.
  final Set<int> lit;

  /// How long the pattern shows: longer for more tiles.
  Duration get showFor => Duration(milliseconds: 1000 + 300 * lit.length);

  MemoryAttempt attempt() => MemoryAttempt(this);
}

class MemoryAttempt {
  MemoryAttempt(this.pattern);

  final MemoryPattern pattern;
  final picked = <int>{};

  GridState get state {
    if (!pattern.lit.containsAll(picked)) return GridState.wrong;
    return picked.length == pattern.lit.length
        ? GridState.right
        : GridState.going;
  }

  /// Whether [cell] is one of the lit tiles. Ignored once finished.
  bool tap(int cell) {
    if (state == GridState.going) picked.add(cell);
    return pattern.lit.contains(cell);
  }
}
