/// Heart rate up (from a watch): pure rule. The first five readings set a
/// baseline; time spent at or above the goal adds up until 15 s.
class HeartRateGoal {
  HeartRateGoal({required this.difficulty});

  static const needed = Duration(seconds: 15);
  static const floor = 90;

  /// A gap longer than this between readings (watch off the wrist, lost
  /// connection) does not count.
  static const _maxGap = Duration(seconds: 3);

  final int difficulty;
  final _first = <int>[];
  int? baseline;
  Duration earned = Duration.zero;
  (int, Duration)? _last;

  int get rise => 10 + 5 * difficulty;
  int? get goal {
    final b = baseline;
    return b == null ? null : (b + rise < floor ? floor : b + rise);
  }

  bool get passed => earned >= needed;
  double get progress =>
      (earned.inMilliseconds / needed.inMilliseconds).clamp(0, 1);

  void add(int bpm, Duration t) {
    if (bpm < 30 || bpm > 230) return; // not a real reading
    if (baseline == null) {
      _first.add(bpm);
      if (_first.length == 5) baseline = ([..._first]..sort())[2];
      _last = (bpm, t);
      return;
    }
    final last = _last;
    if (last != null && last.$1 >= goal!) {
      final dt = t - last.$2;
      if (!dt.isNegative && dt <= _maxGap) earned += dt;
    }
    _last = (bpm, t);
  }
}
