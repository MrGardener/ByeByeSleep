import 'dart:math';

import '../core/types.dart';

/// Arithmetic on a keypad whose digits move after every press.
class BrokenCalculatorDetector {
  BrokenCalculatorDetector({required this.difficulty, required this.random})
    : required = const [1, 2, 2, 3, 3][difficulty.clamp(1, 5) - 1] {
    _keypad.shuffle(random);
    _newProblem();
  }

  static const maxEntryLength = 6;

  final int difficulty;
  final int required;
  final Random random;
  final List<int> _keypad = List.generate(10, (i) => i);
  late String _problem;
  late int _answer;
  String _entry = '';
  int _solved = 0;

  String get problem => _problem;
  List<int> get keypad => List.unmodifiable(_keypad);
  String get entry => _entry;
  ChallengeProgress get progress => _solved >= required
      ? ChallengeProgress.complete
      : ChallengeProgress(_solved / required);

  ChallengeProgress press(int buttonIndex) {
    if (progress.passed) return progress;
    if (_entry.length < maxEntryLength) _entry += '${_keypad[buttonIndex]}';
    _reshuffle();
    return progress;
  }

  ChallengeProgress backspace() {
    if (progress.passed) return progress;
    if (_entry.isNotEmpty) _entry = _entry.substring(0, _entry.length - 1);
    _reshuffle();
    return progress;
  }

  /// Checks the entry. Right or wrong, a new problem follows.
  ChallengeProgress submit() {
    if (progress.passed) return progress;
    if (int.tryParse(_entry) == _answer) _solved++;
    _entry = '';
    if (!progress.passed) _newProblem();
    _reshuffle();
    return progress;
  }

  int _between(int min, int max) => min + random.nextInt(max - min + 1);

  void _newProblem() {
    final previous = _problemOrNull;
    do {
      switch (difficulty.clamp(1, 5)) {
        case 1:
          _set(_between(1, 9), '+', _between(1, 9));
        case 2:
          _set(_between(10, 99), '+', _between(10, 99));
        case 3:
          final a = _between(10, 99);
          final b = _between(10, 99);
          random.nextBool() ? _set(a, '+', b) : _set(max(a, b), '-', min(a, b));
        case 4:
          _set(_between(10, 99), '×', _between(2, 9));
        default:
          final a = _between(10, 99);
          final b = _between(2, 9);
          final c = _between(10, 99);
          _problem = '$a × $b + $c';
          _answer = a * b + c;
      }
    } while (_problem == previous);
  }

  String? get _problemOrNull {
    try {
      return _problem;
    } on Error {
      return null;
    }
  }

  void _set(int a, String op, int b) {
    _problem = '$a $op $b';
    _answer = switch (op) {
      '+' => a + b,
      '-' => a - b,
      _ => a * b,
    };
  }

  void _reshuffle() {
    final before = [..._keypad];
    do {
      _keypad.shuffle(random);
    } while (_sameOrder(before));
  }

  bool _sameOrder(List<int> other) {
    for (var i = 0; i < _keypad.length; i++) {
      if (_keypad[i] != other[i]) return false;
    }
    return true;
  }
}
