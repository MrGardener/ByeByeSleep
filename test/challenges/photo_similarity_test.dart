import 'dart:typed_data';

import 'package:byebyesleep/challenges/photo_match/similarity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A "kitchen": gradient wall, a red cupboard, a blue circle, a yellow strip.
img.Image sceneA({int dx = 0, double brightness = 1}) {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      im.setPixelRgb(x, y, 200 - y ~/ 4, 190 - y ~/ 4, 170 - y ~/ 4);
    }
  }
  img.fillRect(
    im,
    x1: 30 + dx,
    y1: 40,
    x2: 120 + dx,
    y2: 200,
    color: img.ColorRgb8(180, 40, 30),
  );
  img.fillCircle(
    im,
    x: 180 + dx,
    y: 90,
    radius: 40,
    color: img.ColorRgb8(30, 60, 200),
  );
  img.fillRect(
    im,
    x1: 140 + dx,
    y1: 170,
    x2: 250 + dx,
    y2: 190,
    color: img.ColorRgb8(230, 210, 40),
  );
  if (brightness != 1) {
    img.adjustColor(im, brightness: brightness);
  }
  return im;
}

/// A different place: green floor, purple door, white window.
img.Image sceneB() {
  final im = img.Image(width: 256, height: 256);
  img.fill(im, color: img.ColorRgb8(40, 140, 60));
  img.fillRect(
    im,
    x1: 150,
    y1: 20,
    x2: 230,
    y2: 250,
    color: img.ColorRgb8(120, 40, 140),
  );
  img.fillRect(
    im,
    x1: 20,
    y1: 30,
    x2: 100,
    y2: 90,
    color: img.ColorRgb8(245, 245, 245),
  );
  img.drawLine(
    im,
    x1: 0,
    y1: 128,
    x2: 255,
    y2: 200,
    color: img.ColorRgb8(10, 10, 10),
    thickness: 6,
  );
  return im;
}

Uint8List png(img.Image im) => img.encodePng(im);
Uint8List jpg(img.Image im) => img.encodeJpg(im, quality: 85);

void main() {
  test('similarity_identicalIsNearOne', () {
    expect(
      photoSimilarity(png(sceneA()), png(sceneA())),
      greaterThanOrEqualTo(0.99),
    );
  });

  test('similarity_brightnessShiftStillMatches', () {
    final s = photoSimilarity(jpg(sceneA()), jpg(sceneA(brightness: 0.6)));
    expect(s, greaterThanOrEqualTo(0.90));
  });

  test('similarity_smallShiftStillMatches', () {
    expect(
      photoSimilarity(jpg(sceneA()), jpg(sceneA(dx: 2))),
      greaterThanOrEqualTo(0.85),
    );
  });

  test('similarity_differentSceneFails', () {
    expect(photoSimilarity(jpg(sceneA()), jpg(sceneB())), lessThan(0.75));
  });

  test('similarity_garbageIsZero', () {
    expect(photoSimilarity(Uint8List.fromList([1, 2, 3]), png(sceneA())), 0);
  });
}
