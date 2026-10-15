/// Retype: type a cheerful sentence exactly; case and punctuation do not
/// matter. Pure Dart.
library;

import 'dart:math';

/// Built-in sentences, shortest tier first (difficulty 1 … 5).
const morningSentences = <List<String>>[
  [
    'Rise and shine!',
    'Good morning, sunshine.',
    'Hello, bright new day.',
    'Time to wake up.',
    'The sun is up.',
  ],
  [
    'Today is going to be great.',
    'A warm cup of tea awaits.',
    'The birds are singing outside.',
    'Open the curtains and smile.',
    'Fresh air feels so good.',
  ],
  [
    'Every morning is a fresh start for me.',
    'I am awake and ready for the day.',
    'A glass of water and a big stretch.',
    'The coffee smells wonderful this morning.',
    "Let's make today a really good one.",
  ],
  [
    'The early morning light is soft and golden over the hills.',
    'I will drink some water, stretch and then make breakfast.',
    'Small steps every morning add up to a wonderful life.',
    "Today I'll be kind, curious and a little bit brave.",
    'The kettle is singing and the toast is nearly ready.',
  ],
  [
    'Good morning! The sun is shining, the birds are singing and '
        'today is full of possibilities.',
    'Wake up slowly, take a deep breath, smile and step into a '
        'bright new day.',
    'A warm breakfast, a good stretch and a happy song are the best '
        'way to begin.',
    "I'm out of bed, my feet are on the floor and I'm ready for "
        'whatever comes next.',
    'Every sunrise is a gentle reminder that we get to start again '
        'with fresh eyes.',
  ],
];

/// Lower case, apostrophes and other punctuation dropped, single spaces.
String normaliseSentence(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
    .trim()
    .split(RegExp(r'\s+'))
    .join(' ');

class Retype {
  const Retype(this.sentence);

  factory Retype.random(Random random, int difficulty) {
    final tier = morningSentences[difficulty.clamp(1, 5) - 1];
    return Retype(tier[random.nextInt(tier.length)]);
  }

  final String sentence;

  bool accepts(String typed) =>
      normaliseSentence(typed) == normaliseSentence(sentence);

  /// How many words, from the start, are already right.
  int wordsRight(String typed) {
    final want = normaliseSentence(sentence).split(' ');
    final got = normaliseSentence(typed).split(' ');
    var i = 0;
    while (i < want.length && i < got.length && want[i] == got[i]) {
      i++;
    }
    return i;
  }

  int get wordCount => normaliseSentence(sentence).split(' ').length;
}
