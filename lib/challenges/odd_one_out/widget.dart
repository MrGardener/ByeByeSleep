import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/challenge.dart';
import '../core/tile_grid.dart';
import 'rule.dart';

/// Lopsided symbols, so a turned one can be told apart.
const _glyphs = [
  Icons.music_note,
  Icons.navigation,
  Icons.flight,
  Icons.directions_run,
  Icons.local_cafe,
  Icons.emoji_nature,
];

/// Odd one out: one symbol in the grid is turned a little; tap it, three
/// times in a row.
class OddOneOutChallenge extends StatefulWidget {
  const OddOneOutChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<OddOneOutChallenge> createState() => _OddOneOutState();
}

class _OddOneOutState extends State<OddOneOutChallenge> {
  late final OddOneOut _game = OddOneOut(
    widget.args.difficulty,
    widget.args.random,
    fixedOdd: widget.args.params['odd'] as int?, // tests
  );
  String? _message;
  bool _done = false;

  void _tap(int cell) {
    if (_done) return;
    final right = _game.tap(cell);
    setState(
      () => _message = _game.passed
          ? 'Sharp eyes!'
          : right
          ? 'Found it! Next one…'
          : 'Not that one. Back to 0 — keep looking.',
    );
    if (_game.passed) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = _game.size;
    final glyph = _glyphs[_game.round.glyph % _glyphs.length];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tap the one that is turned', style: text.titleMedium),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < OddOneOut.rounds; i++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  i < _game.streak ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: i < _game.streak
                      ? SunriseColors.of(context).success
                      : scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 4),
            Text(
              '${_game.streak} / ${OddOneOut.rounds}',
              key: const Key('odd-streak'),
            ),
          ],
        ),
        SizedBox(height: 28, child: _message == null ? null : Text(_message!)),
        Flexible(
          child: TileGrid(
            cols: n,
            rows: n,
            maxCell: 88,
            cell: (i, size) => Material(
              key: Key('odd-$i'),
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _tap(i),
                child: Center(
                  child: Transform.rotate(
                    angle: i == _game.round.odd
                        ? _game.angleDegrees * pi / 180
                        : 0,
                    child: Icon(glyph, size: size * 0.6, color: scheme.primary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
