import 'dart:io';

import 'package:byebyesleep/game/progress_store.dart';
import 'package:byebyesleep/game/quest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late FileProgressStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('quest');
    store = FileProgressStore(() async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('missing file loads nothing', () async {
    expect(await store.load(), isEmpty);
  });

  test('save then load round-trips', () async {
    await store.save({World.batteryOracle, World.labyrinth});
    expect(await store.load(), {World.batteryOracle, World.labyrinth});
  });

  test('corrupt file loads nothing', () async {
    File('${dir.path}/quest.json').writeAsStringSync('{not json');
    expect(await store.load(), isEmpty);
  });

  test('unknown world names are ignored', () async {
    File('${dir.path}/quest.json')
        .writeAsStringSync('{"completed":["batteryOracle","atlantis",3]}');
    expect(await store.load(), {World.batteryOracle});
  });
}
