import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../core/challenge.dart';
import 'word.dart';

/// Word unscramble: tap the letter tiles in the right order.
class WordUnscrambleChallenge extends StatefulWidget {
  const WordUnscrambleChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  State<WordUnscrambleChallenge> createState() => _WordUnscrambleState();
}

class _WordUnscrambleState extends State<WordUnscrambleChallenge> {
  late final Unscramble _u = Unscramble.random(
    widget.args.random,
    widget.args.difficulty,
    word: widget.args.params['word'] as String?, // tests
  );
  String? _message;
  bool _done = false;

  void _pick(int tile) {
    if (_done) return;
    setState(() {
      _u.pick(tile);
      _message = null;
      switch (_u.state) {
        case WordState.right:
          _message = 'Unscrambled!';
        case WordState.wrong:
          _message = 'Not quite: "${_u.guess.toUpperCase()}". Try again.';
          _u.clear();
        case WordState.going:
      }
    });
    if (_u.state == WordState.right) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final guess = _u.guess;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Make a ${_u.word.length}-letter word', style: text.titleMedium),
        const SizedBox(height: 12),
        // The answer so far, one slot per letter.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _u.word.length; i++)
              Container(
                width: 36,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.primary, width: 3),
                  ),
                ),
                child: Text(
                  i < guess.length ? guess[i].toUpperCase() : '',
                  style: text.headlineSmall,
                ),
              ),
          ],
        ),
        SizedBox(
          height: 32,
          child: _message == null
              ? null
              : Center(child: Text(_message!, textAlign: TextAlign.center)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < _u.tiles.length; i++)
              // Keyed by position: a word can repeat a letter.
              KeyedSubtree(
                key: ValueKey(i),
                child: _LetterTile(
                  key: Key(
                    _u.picked.contains(i)
                        ? 'tile-used-$i'
                        : 'tile-${_u.tiles[i]}',
                  ),
                  letter: _u.tiles[i],
                  onTap: _u.picked.contains(i) ? null : () => _pick(i),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('unscramble-undo'),
              onPressed: guess.isEmpty || _done
                  ? null
                  : () => setState(_u.undo),
              icon: const Icon(Icons.backspace_outlined),
              label: const Text('Undo'),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              key: const Key('unscramble-clear'),
              onPressed: guess.isEmpty || _done
                  ? null
                  : () => setState(_u.clear),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({super.key, required this.letter, required this.onTap});

  final String letter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        minimumSize: const Size.square(56),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
        ),
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        textStyle: Theme.of(context).textTheme.headlineSmall,
      ),
      child: Text(letter.toUpperCase()),
    );
  }
}
