import 'dart:io';
import 'dart:typed_data';

import 'package:byebyesleep/challenges/photo_match/similarity.dart';
import 'package:byebyesleep/challenges/photo_match/widget.dart';
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

/// Low-saturation rooms, like real indoor photos.
img.Image beigeRoom({int dx = 0}) {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      im.setPixelRgb(x, y, 210 - y ~/ 8, 200 - y ~/ 8, 185 - y ~/ 8);
    }
  }
  img.fillRect(
    im,
    x1: 40 + dx,
    y1: 60,
    x2: 110 + dx,
    y2: 250,
    color: img.ColorRgb8(120, 100, 85),
  );
  img.drawRect(
    im,
    x1: 150 + dx,
    y1: 50,
    x2: 220 + dx,
    y2: 120,
    color: img.ColorRgb8(60, 55, 50),
    thickness: 4,
  );
  img.drawLine(
    im,
    x1: 0,
    y1: 200,
    x2: 255,
    y2: 200,
    color: img.ColorRgb8(150, 140, 130),
    thickness: 3,
  );
  return im;
}

img.Image greyRoom() {
  final im = img.Image(width: 256, height: 256);
  img.fill(im, color: img.ColorRgb8(190, 190, 185));
  img.fillRect(
    im,
    x1: 130,
    y1: 20,
    x2: 240,
    y2: 140,
    color: img.ColorRgb8(230, 232, 235),
  );
  for (var y = 160; y < 250; y += 30) {
    img.drawLine(
      im,
      x1: 10,
      y1: y,
      x2: 110,
      y2: y,
      color: img.ColorRgb8(90, 85, 80),
      thickness: 3,
    );
  }
  return im;
}

img.Image blankWall() {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      im.setPixelRgb(x, y, 205 - x ~/ 16, 195 - x ~/ 16, 180 - x ~/ 16);
    }
  }
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

  test('similarity_handheldShiftStillMatches', () {
    // A 6% sideways step, like retaking the photo by hand.
    expect(
      photoSimilarity(jpg(sceneA()), jpg(sceneA(dx: 16, brightness: 0.8))),
      greaterThanOrEqualTo(0.75),
    );
  });

  group('real photos', () {
    Uint8List photo(String name) =>
        File('test/fixtures/photos/$name.jpg').readAsBytesSync();
    const scenes = ['boston', 'kalimba', 'cat'];

    test('handheld retakes (shift, tilt, zoom, light, blur) match', () {
      for (final s in scenes) {
        for (final v in ['v3', 'v5']) {
          expect(
            photoSimilarity(photo('${s}_ref'), photo('${s}_$v')),
            greaterThanOrEqualTo(0.7),
            reason: '$s $v',
          );
        }
      }
    });

    test('other places stay far below the default threshold', () {
      for (final a in scenes) {
        for (final b in scenes.where((b) => b != a)) {
          expect(
            photoSimilarity(photo('${a}_ref'), photo('${b}_v3')),
            lessThan(defaultPhotoThreshold - 0.15),
            reason: '$a vs $b',
          );
        }
      }
    });
  });

  test('similarity_differentSceneFails', () {
    expect(photoSimilarity(jpg(sceneA()), jpg(sceneB())), lessThan(0.45));
  });

  test('similarity_dullDifferentRoomsFail', () {
    expect(photoSimilarity(jpg(beigeRoom()), jpg(greyRoom())), lessThan(0.45));
  });

  test('similarity_blankWallFails', () {
    expect(photoSimilarity(jpg(beigeRoom()), jpg(blankWall())), lessThan(0.45));
    expect(photoSimilarity(jpg(blankWall()), jpg(greyRoom())), lessThan(0.45));
  });

  test('similarity_sameDullRoomShiftedMatches', () {
    expect(
      photoSimilarity(jpg(beigeRoom()), jpg(beigeRoom(dx: 4))),
      greaterThanOrEqualTo(0.85),
    );
  });

  test('similarity_garbageIsZero', () {
    expect(photoSimilarity(Uint8List.fromList([1, 2, 3]), png(sceneA())), 0);
  });
}
