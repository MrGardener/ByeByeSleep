/// Time sense: stop the hidden timer as close to the target as you can.
/// Pure Dart.
library;

class TimeSense {
  const TimeSense(this.target, this.tolerance);

  /// 20 s ±3 s at difficulty 1 … 45 s ±1 s at 5.
  factory TimeSense.forDifficulty(int difficulty) {
    final d = difficulty.clamp(1, 5) - 1;
    return TimeSense(
      Duration(seconds: const [20, 25, 30, 40, 45][d]),
      Duration(milliseconds: const [3000, 2500, 2000, 1500, 1000][d]),
    );
  }

  final Duration target;
  final Duration tolerance;

  bool accepts(Duration elapsed) => (elapsed - target).abs() <= tolerance;

  String feedback(Duration elapsed) {
    final off = (elapsed - target).inMilliseconds / 1000;
    return '${off > 0 ? 'Too slow' : 'Too fast'} by '
        '${off.abs().toStringAsFixed(1)} s';
  }
}
