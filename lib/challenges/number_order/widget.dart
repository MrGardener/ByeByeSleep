import 'package:flutter/material.dart';

import '../core/challenge.dart';
import '../core/tile_grid.dart';
import 'rule.dart';

/// Number order: tap the numbers from 1 upwards; a wrong one starts again.
class NumberOrderChallenge extends StatefulWidget {
  const NumberOrderChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<NumberOrderChallenge> createState() => _NumberOrderState();
}

class _NumberOrderState extends State<NumberOrderChallenge> {
  late final NumberBoard _board = NumberBoard.random(
    widget.args.random,
    widget.args.difficulty,
    count: widget.args.params['count'] as int?, // tests
  );
  late final Map<int, int> _numberAt = {
    for (var i = 0; i < _board.count; i++) _board.cellOf[i]: i + 1,
  };
  String? _message;
  bool _done = false;

  void _tap(int n) {
    if (_done) return;
    final result = _board.tap(n);
    setState(
      () => _message = switch (result) {
        NumberTap.wrong => 'That was $n, not the next one. Start again at 1.',
        NumberTap.done => 'All in order!',
        NumberTap.right => null,
      },
    );
    if (result == NumberTap.done) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _done ? 'Done' : 'Tap ${_board.next} next (1 to ${_board.count})',
          key: const Key('number-next'),
          style: text.titleMedium,
        ),
        SizedBox(
          height: 40,
          child: _message == null
              ? null
              : Text(_message!, textAlign: TextAlign.center),
        ),
        Flexible(
          child: TileGrid(
            cols: _board.cols,
            rows: _board.rows,
            maxCell: 80,
            cell: (cell, size) {
              final n = _numberAt[cell];
              if (n == null) return const SizedBox.shrink();
              final tapped = n < _board.next;
              return FilledButton.tonal(
                key: Key('number-$n'),
                onPressed: tapped ? null : () => _tap(n),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.square(size),
                  shape: const CircleBorder(),
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  textStyle: text.titleLarge,
                ),
                child: Text('$n'),
              );
            },
          ),
        ),
      ],
    );
  }
}
