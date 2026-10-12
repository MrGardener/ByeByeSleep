import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _size = 64;
const _hueBins = 18;
const _satBins = 4;

/// How alike two photos of the same place are, 0.0–1.0 (spec §4.3).
///
/// Half colour (hue/saturation histogram, brightness ignored) and half
/// structure (edge map of brightness-normalised grayscale), so switching the
/// light on or off changes little while a different place scores low.
/// Undecodable input scores 0.
double photoSimilarity(Uint8List a, Uint8List b) {
  final ia = _prepare(a);
  final ib = _prepare(b);
  if (ia == null || ib == null) return 0;
  final colour = _correlation(_histogram(ia), _histogram(ib));
  final structure = _correlation(_edges(ia), _edges(ib));
  // Unrelated (r ≈ 0) or opposite (r < 0) counts as no similarity; mapping
  // −1..1 onto 0..1 instead gave unrelated rooms a floor of about 0.75.
  return (0.5 * max(0.0, colour) + 0.5 * max(0.0, structure)).clamp(0.0, 1.0);
}

img.Image? _prepare(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    return img.copyResize(
      decoded,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
  } on Object {
    return null;
  }
}

List<double> _histogram(img.Image im) {
  final bins = List<double>.filled(_hueBins * _satBins, 0);
  for (final p in im) {
    final r = p.r / 255, g = p.g / 255, b = p.b / 255;
    final mx = max(r, max(g, b)), mn = min(r, min(g, b));
    final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
    final satBin = min(_satBins - 1, (sat * _satBins).floor());
    var hueBin = 0; // greys share one bin per saturation level
    if (satBin > 0 && mx != mn) {
      double hue;
      if (mx == r) {
        hue = ((g - b) / (mx - mn)) % 6;
      } else if (mx == g) {
        hue = (b - r) / (mx - mn) + 2;
      } else {
        hue = (r - g) / (mx - mn) + 4;
      }
      hueBin = min(_hueBins - 1, (hue / 6 * _hueBins).floor());
    }
    bins[satBin * _hueBins + hueBin]++;
  }
  return bins;
}

List<double> _edges(img.Image im) {
  final gray = List<double>.generate(_size * _size, (i) {
    final p = im.getPixel(i % _size, i ~/ _size);
    return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  });
  final mean = gray.reduce((x, y) => x + y) / gray.length;
  final sd = sqrt(
    gray.map((v) => (v - mean) * (v - mean)).reduce((x, y) => x + y) /
        gray.length,
  );
  final norm = [for (final v in gray) sd == 0 ? 0.0 : (v - mean) / sd];
  double at(int x, int y) => norm[y * _size + x];
  final out = <double>[];
  for (var y = 1; y < _size - 1; y++) {
    for (var x = 1; x < _size - 1; x++) {
      final gx =
          at(x + 1, y - 1) +
          2 * at(x + 1, y) +
          at(x + 1, y + 1) -
          at(x - 1, y - 1) -
          2 * at(x - 1, y) -
          at(x - 1, y + 1);
      final gy =
          at(x - 1, y + 1) +
          2 * at(x, y + 1) +
          at(x + 1, y + 1) -
          at(x - 1, y - 1) -
          2 * at(x, y - 1) -
          at(x + 1, y - 1);
      out.add(sqrt(gx * gx + gy * gy));
    }
  }
  return out;
}

/// Pearson correlation; 0 when either side is constant.
double _correlation(List<double> a, List<double> b) {
  final n = a.length;
  final ma = a.reduce((x, y) => x + y) / n;
  final mb = b.reduce((x, y) => x + y) / n;
  var cov = 0.0, va = 0.0, vb = 0.0;
  for (var i = 0; i < n; i++) {
    final da = a[i] - ma, db = b[i] - mb;
    cov += da * db;
    va += da * da;
    vb += db * db;
  }
  if (va == 0 || vb == 0) return 0;
  return cov / sqrt(va * vb);
}
