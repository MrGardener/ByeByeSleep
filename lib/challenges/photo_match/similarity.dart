import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const _size = 64;

/// Border (in pixels at [_size]) left out of the comparison: after shifting
/// or turning one photo, its edge has no counterpart in the other.
const _margin = 10;

/// How alike two photos of the same place are, 0.0–1.0 (spec §4.3).
///
/// Compares structure: the direction and strength of brightness edges, which
/// barely change with the light. A photo retaken by hand is never in exactly
/// the same spot, so the second photo is first lined up with the first: up to
/// 12% sideways or up/down, 8% closer or further and 4° tilted, keeping the
/// best fit. Unrelated places stay low because no fit lines their edges up.
/// Undecodable or featureless input (a blank wall, a covered lens) scores 0.
double photoSimilarity(Uint8List a, Uint8List b) {
  final fa = _features(a);
  final fb = _features(b);
  if (fa == null || fb == null) return 0;
  var best = 0.0;
  for (final scale in const [0.92, 1.0, 1.08]) {
    for (final degrees in const [-4.0, 0.0, 4.0]) {
      for (var dy = -8; dy <= 8; dy += 2) {
        for (var dx = -8; dx <= 8; dx += 2) {
          final s = _fit(fa, fb, dx, dy, scale, degrees * pi / 180);
          if (s > best) best = s;
        }
      }
    }
  }
  return best.clamp(0.0, 1.0);
}

/// Edge field of a photo: horizontal and vertical brightness gradients.
class _Features {
  _Features(this.gx, this.gy);

  final Float64List gx;
  final Float64List gy;
}

_Features? _features(Uint8List bytes) {
  final img.Image small;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    small = img.copyResize(
      img.bakeOrientation(decoded),
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
  } on Object {
    return null;
  }
  const n = _size * _size;
  final gray = Float64List(n);
  for (var i = 0; i < n; i++) {
    final p = small.getPixel(i % _size, i ~/ _size);
    gray[i] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
  }
  // Brightness-normalise, so lighting and exposure do not matter.
  var mean = 0.0;
  for (final v in gray) {
    mean += v;
  }
  mean /= n;
  var variance = 0.0;
  for (final v in gray) {
    variance += (v - mean) * (v - mean);
  }
  final sd = sqrt(variance / n);
  if (sd < 2) return null; // featureless: nothing to match
  for (var i = 0; i < n; i++) {
    gray[i] = (gray[i] - mean) / sd;
  }
  final g = _blur(gray);
  final gx = Float64List(n), gy = Float64List(n);
  for (var y = 1; y < _size - 1; y++) {
    for (var x = 1; x < _size - 1; x++) {
      final i = y * _size + x;
      gx[i] = g[i + 1] - g[i - 1];
      gy[i] = g[i + _size] - g[i - _size];
    }
  }
  // Blurring the edges tolerates what the alignment grid steps over.
  return _Features(_blur(gx), _blur(gy));
}

/// 3×3 box blur, edges clamped.
Float64List _blur(Float64List a) {
  final out = Float64List(a.length);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      var sum = 0.0;
      for (var oy = -1; oy <= 1; oy++) {
        final yy = (y + oy).clamp(0, _size - 1);
        for (var ox = -1; ox <= 1; ox++) {
          sum += a[yy * _size + (x + ox).clamp(0, _size - 1)];
        }
      }
      out[y * _size + x] = sum / 9;
    }
  }
  return out;
}

/// Cosine similarity of the edge fields, with [b] moved by (dx, dy), scaled
/// and rotated about the centre, over the inner area.
double _fit(
  _Features a,
  _Features b,
  int dx,
  int dy,
  double scale,
  double rot,
) {
  const c = (_size - 1) / 2;
  final cosR = cos(rot) * scale, sinR = sin(rot) * scale;
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var y = _margin; y < _size - _margin; y++) {
    for (var x = _margin; x < _size - _margin; x++) {
      final x0 = x - c, y0 = y - c;
      final u = (cosR * x0 - sinR * y0 + c + dx).clamp(0.0, _size - 1.001);
      final v = (sinR * x0 + cosR * y0 + c + dy).clamp(0.0, _size - 1.001);
      final x1 = u.floor(), y1 = v.floor();
      final fx = u - x1, fy = v - y1;
      final i = y1 * _size + x1;
      final w00 = (1 - fx) * (1 - fy), w10 = fx * (1 - fy);
      final w01 = (1 - fx) * fy, w11 = fx * fy;
      final bx =
          b.gx[i] * w00 +
          b.gx[i + 1] * w10 +
          b.gx[i + _size] * w01 +
          b.gx[i + _size + 1] * w11;
      final by =
          b.gy[i] * w00 +
          b.gy[i + 1] * w10 +
          b.gy[i + _size] * w01 +
          b.gy[i + _size + 1] * w11;
      final j = y * _size + x;
      final ax = a.gx[j], ay = a.gy[j];
      dot += ax * bx + ay * by;
      na += ax * ax + ay * ay;
      nb += bx * bx + by * by;
    }
  }
  if (na == 0 || nb == 0) return 0;
  return dot / sqrt(na * nb);
}
