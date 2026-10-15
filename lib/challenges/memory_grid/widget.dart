import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/challenge.dart';
import '../core/tile_grid.dart';
import 'rule.dart';

/// Memory grid: watch which tiles light up, then tap the same tiles.
class MemoryGridChallenge extends StatefulWidget {
  const MemoryGridChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<MemoryGridChallenge> createState() => _MemoryGridState();
}

class _MemoryGridState extends State<MemoryGridChallenge> {
  late final MemoryPattern _pattern = MemoryPattern.forDifficulty(
    widget.args.difficulty,
    widget.args.random,
    tiles: (widget.args.params['tiles'] as List?)?.cast<int>(),
  );
  late MemoryAttempt _attempt = _pattern.attempt();
  var _phase = _Phase.showing;
  String? _message;
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _show();
  }

  /// Lights the pattern for a moment, then lets you tap.
  void _show() {
    _timer?.cancel();
    setState(() {
      _phase = _Phase.showing;
      _attempt = _pattern.attempt();
    });
    _timer = Timer(_pattern.showFor, () {
      if (mounted) setState(() => _phase = _Phase.input);
    });
  }

  void _tap(int cell) {
    if (_phase != _Phase.input || _done) return;
    _attempt.tap(cell);
    switch (_attempt.state) {
      case GridState.right:
        _done = true;
        setState(() => _message = 'Perfect memory!');
        widget.args.onPassed();
      case GridState.wrong:
        setState(() {
          _phase = _Phase.mistake; // no taps until it has shown again
          _message = 'Wrong tile — watch again.';
        });
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) _show();
        });
      case GridState.going:
        setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = _pattern.size;
    final found = _attempt.picked.where(_pattern.lit.contains).length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _phase == _Phase.showing
              ? 'Watch the ${_pattern.lit.length} lit tiles…'
              : 'Tap the tiles that lit up '
                    '($found of ${_pattern.lit.length}).',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 24, child: _message == null ? null : Text(_message!)),
        const SizedBox(height: 8),
        Flexible(
          child: TileGrid(
            cols: n,
            rows: n,
            cell: (i, _) => Material(
              key: Key('memory-$i'),
              color: _colourOf(i, scheme),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () => _tap(i)),
            ),
          ),
        ),
      ],
    );
  }

  Color _colourOf(int i, ColorScheme scheme) {
    final lit = _pattern.lit.contains(i);
    if (_phase == _Phase.showing) {
      return lit ? scheme.tertiary : scheme.surfaceContainerHighest;
    }
    if (!_attempt.picked.contains(i)) return scheme.surfaceContainerHighest;
    return lit ? SunriseColors.of(context).success : scheme.error;
  }
}

/// Showing the pattern, showing a mistake, or waiting for taps.
enum _Phase { showing, mistake, input }
