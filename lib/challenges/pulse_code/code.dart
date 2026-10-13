/// Pulse code: watch a code of short and long flashes, tap it back. Pure Dart.
library;

import 'dart:math';

enum Pulse { short, long }

enum AttemptState { going, right, wrong }

/// One step of the flash animation.
class Flash {
  const Flash(this.on, this.length);
  final bool on;
  final Duration length;
}

class PulseCode {
  const PulseCode(this.pulses);

  /// 3 pulses at difficulty 1 … 7 at 5.
  factory PulseCode.random(Random random, int difficulty) => PulseCode([
    for (var i = 0; i < 2 + difficulty.clamp(1, 5); i++)
      random.nextBool() ? Pulse.long : Pulse.short,
  ]);

  static const unit = Duration(milliseconds: 300);

  final List<Pulse> pulses;

  /// Short = 1 unit on, long = 3 units on; each followed by a gap.
  List<Flash> timeline() => [
    for (final p in pulses) ...[
      Flash(true, p == Pulse.long ? unit * 3 : unit),
      Flash(false, unit * 1.5),
    ],
  ];

  CodeAttempt attempt() => CodeAttempt(this);
}

class CodeAttempt {
  CodeAttempt(this.code);

  final PulseCode code;
  final typed = <Pulse>[];

  AttemptState get state {
    for (var i = 0; i < typed.length; i++) {
      if (typed[i] != code.pulses[i]) return AttemptState.wrong;
    }
    return typed.length == code.pulses.length
        ? AttemptState.right
        : AttemptState.going;
  }

  void add(Pulse p) {
    if (state == AttemptState.going) typed.add(p);
  }
}
