import 'dart:collection';
import 'dart:math';

enum Direction { north, east, south, west }

/// A perfect maze (exactly one path between any two cells) on a square grid.
/// Cells are numbered row by row: cell = y * size + x. Start is cell 0, the
/// goal is the last cell.
class Maze {
  Maze._(this.size, this._walls);

  /// Recursive backtracker (iterative, so big mazes cannot overflow the stack).
  factory Maze.generate(int size, Random random) {
    final walls = List.filled(size * size, 0xF);
    final maze = Maze._(size, walls);
    final visited = List.filled(size * size, false)..[0] = true;
    final stack = [0];
    while (stack.isNotEmpty) {
      final cell = stack.last;
      final options = [
        for (final d in Direction.values)
          if (maze._inside(cell, d) && !visited[maze.neighbour(cell, d)]) d,
      ];
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = options[random.nextInt(options.length)];
      final next = maze.neighbour(cell, d);
      walls[cell] &= ~_bit(d);
      walls[next] &= ~_bit(_opposite(d));
      visited[next] = true;
      stack.add(next);
    }
    return maze;
  }

  /// No inner walls, only the border (physics tests).
  factory Maze.open(int size) {
    final maze = Maze._(size, List.filled(size * size, 0));
    for (var c = 0; c < size * size; c++) {
      for (final d in Direction.values) {
        if (!maze._inside(c, d)) maze._walls[c] |= _bit(d);
      }
    }
    return maze;
  }

  final int size;
  final List<int> _walls;

  int get goal => size * size - 1;

  bool wall(int cell, Direction d) => _walls[cell] & _bit(d) != 0;

  int neighbour(int cell, Direction d) => switch (d) {
    Direction.north => cell - size,
    Direction.east => cell + 1,
    Direction.south => cell + size,
    Direction.west => cell - 1,
  };

  /// Cells from start to goal along the only path.
  List<int> solve() {
    final previous = <int, int>{0: -1};
    final queue = Queue.of([0]);
    while (queue.isNotEmpty) {
      final c = queue.removeFirst();
      if (c == goal) break;
      for (final d in Direction.values) {
        if (wall(c, d)) continue;
        final n = neighbour(c, d);
        if (previous.containsKey(n)) continue;
        previous[n] = c;
        queue.add(n);
      }
    }
    final path = <int>[];
    for (var c = goal; c != -1; c = previous[c]!) {
      path.add(c);
    }
    return path.reversed.toList();
  }

  bool _inside(int cell, Direction d) {
    final x = cell % size, y = cell ~/ size;
    return switch (d) {
      Direction.north => y > 0,
      Direction.east => x < size - 1,
      Direction.south => y < size - 1,
      Direction.west => x > 0,
    };
  }

  static int _bit(Direction d) => 1 << d.index;

  static Direction _opposite(Direction d) =>
      Direction.values[(d.index + 2) % 4];
}
