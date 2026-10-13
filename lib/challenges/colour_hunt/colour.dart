/// Colour hunt: is the middle of the photo clearly a given colour? Pure Dart.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum HuntColour {
  red('red'),
  yellow('yellow'),
  green('green'),
  blue('blue'),
  purple('purple');

  const HuntColour(this.label);
  final String label;
}

/// The colour filling the middle half of the photo, or null when it is
/// grey, white, black, too pale or the photo cannot be read. Brightness is
/// ignored, so a dim room still works.
HuntColour? centreColour(Uint8List bytes) {
  img.Image small;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    small = img.copyResize(
      img.bakeOrientation(decoded),
      width: 40,
      height: 40,
      interpolation: img.Interpolation.average,
    );
  } on Object {
    return null;
  }
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  for (var y = 10; y < 30; y++) {
    for (var x = 10; x < 30; x++) {
      final p = small.getPixel(x, y);
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
  }
  r /= n * 255;
  g /= n * 255;
  b /= n * 255;
  final mx = max(r, max(g, b)), mn = min(r, min(g, b));
  if (mx < 0.15) return null; // too dark to tell
  final saturation = (mx - mn) / mx;
  if (saturation < 0.35) return null; // grey or white
  double hue;
  if (mx == r) {
    hue = 60 * (((g - b) / (mx - mn)) % 6);
  } else if (mx == g) {
    hue = 60 * ((b - r) / (mx - mn) + 2);
  } else {
    hue = 60 * ((r - g) / (mx - mn) + 4);
  }
  if (hue < 15 || hue >= 345) return HuntColour.red;
  // Orange, skin and wood are none of the colours asked for: a hand in
  // front of the lens must not pass as red.
  if (hue < 42) return null;
  if (hue < 70) return HuntColour.yellow;
  if (hue < 170) return HuntColour.green;
  if (hue < 260) return HuntColour.blue;
  return HuntColour.purple;
}
