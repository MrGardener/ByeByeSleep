import 'dart:io';
import 'dart:typed_data';

import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/alarm/series.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/challenges/core/camera.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_alarm_platform.dart';

class RecordingStore implements PhotoStore {
  final kept = <Set<String>>[];

  @override
  Future<String> save(Uint8List bytes) async => 'x';

  @override
  Future<Uint8List?> load(String path) async => null;

  @override
  Future<void> keepOnly(Set<String> used) async => kept.add(used);
}

void main() {
  final withPhotos = Alarm(
    id: 1,
    hour: 7,
    minute: 0,
    reminder: const Reminder(photoPath: '/p/keys.jpg', caption: 'Keys'),
    stages: const [
      StageConfig(
        ChallengeId.photoMatch,
        params: {
          'photos': ['/p/a.jpg', '/p/b.jpg'],
        },
      ),
    ],
  );

  test('photos in use: reminders and photo-match references', () {
    expect(photosInUse([withPhotos, Alarm(id: 2, hour: 8, minute: 0)]), {
      '/p/keys.jpg',
      '/p/a.jpg',
      '/p/b.jpg',
    });
  });

  test('the file store deletes only photos nobody uses', () async {
    final dir = Directory.systemTemp.createTempSync('photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = FilePhotoStore(dir: () async => dir);
    final keep = await store.save(Uint8List.fromList([1]));
    final drop = await store.save(Uint8List.fromList([2]));
    await store.keepOnly({keep});
    expect(File(keep).existsSync(), isTrue);
    expect(File(drop).existsSync(), isFalse);
  });

  test(
    'deleting an alarm lets its photos go; a failed save keeps all',
    () async {
      final store = RecordingStore();
      final fake = FakeAlarmPlatform(seed: [withPhotos]);
      final c = ProviderContainer(
        overrides: [
          alarmPlatformProvider.overrideWithValue(fake),
          photoStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(alarmListProvider.notifier);
      await c.read(alarmListProvider.future);
      fake.failOn = (call) => call.startsWith('upsert');
      await expectLater(
        n.save(withPhotos.copyWith(hour: 9)),
        throwsA(anything),
      );
      expect(store.kept, isEmpty);
      await n.remove(1);
      await Future<void>.delayed(Duration.zero);
      expect(store.kept.last, isEmpty);
    },
  );
}
