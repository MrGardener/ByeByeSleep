/// Word unscramble: rebuild a word from its shuffled letters. Pure Dart.
library;

import 'dart:math';

/// Built-in words: 4 letters at difficulty 1 … 8 at 5. Words that are an
/// anagram of another common word (garden/danger) are left out.
const unscrambleWords = <List<String>>[
  ['wake', 'yawn', 'milk', 'jump', 'bird', 'warm', 'walk', 'hope', 'cozy'],
  ['sunny', 'toast', 'light', 'happy', 'fruit', 'honey', 'cheer', 'juice'],
  ['coffee', 'breeze', 'cereal', 'pillow', 'energy', 'bright', 'window'],
  ['morning', 'sunrise', 'pancake', 'blanket', 'stretch', 'rainbow'],
  ['sunshine', 'daylight', 'birdsong', 'cheerful', 'sandwich', 'mountain'],
];

enum WordState { going, right, wrong }

class Unscramble {
  Unscramble(this.word, this.tiles);

  /// A word for [difficulty] ([word] overrides), its letters shuffled so the
  /// tiles never spell it already.
  factory Unscramble.random(Random random, int difficulty, {String? word}) {
    final tier = unscrambleWords[difficulty.clamp(1, 5) - 1];
    final w = word ?? tier[random.nextInt(tier.length)];
    final tiles = w.split('');
    for (var i = 0; i < 20 && tiles.join() == w; i++) {
      tiles.shuffle(random);
    }
    if (tiles.join() == w) tiles.add(tiles.removeAt(0)); // still: rotate
    return Unscramble(w, tiles);
  }

  final String word;
  final List<String> tiles;

  /// Tile indices picked so far, in order.
  final picked = <int>[];

  String get guess => picked.map((i) => tiles[i]).join();

  WordState get state => picked.length < word.length
      ? WordState.going
      : guess == word
      ? WordState.right
      : WordState.wrong;

  void pick(int tile) {
    if (picked.length < word.length && !picked.contains(tile)) {
      picked.add(tile);
    }
  }

  void undo() {
    if (picked.isNotEmpty) picked.removeLast();
  }

  void clear() => picked.clear();
}
