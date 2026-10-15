/// Number order: tap 1…N, scattered over a grid, in order. Pure Dart.
library;

import 'dart:math';

enum NumberTap { right, wrong, done }

class NumberBoard {
  NumberBoard(this.cols, this.rows, this.cellOf);

  /// 9 numbers at difficulty 1 … 25 at 5 ([count] overrides), in random
  /// cells of a grid with some cells left empty.
  factory NumberBoard.random(Random random, int difficulty, {int? count}) {
    final n = count ?? const [9, 12, 16, 20, 25][difficulty.clamp(1, 5) - 1];
    final cols = n <= 12 ? 4 : 5;
    final rows = ((n + max(1, n ~/ 5)) / cols).ceil();
    final cells = List.generate(cols * rows, (i) => i)..shuffle(random);
    return NumberBoard(cols, rows, cells.take(n).toList());
  }

  final int cols;
  final int rows;

  /// The cell (row by row) of number i + 1.
  final List<int> cellOf;

  int get count => cellOf.length;

  /// The number to tap next; count + 1 when finished.
  int next = 1;

  bool get done => next > count;

  /// A wrong number starts again from 1.
  NumberTap tap(int n) {
    if (done) return NumberTap.done;
    if (n != next) {
      next = 1;
      return NumberTap.wrong;
    }
    next++;
    return done ? NumberTap.done : NumberTap.right;
  }
}
