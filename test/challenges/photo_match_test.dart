import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:byebyesleep/challenges/core/camera.dart';
import 'package:byebyesleep/challenges/core/challenge.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:byebyesleep/challenges/photo_match/setup.dart';
import 'package:byebyesleep/challenges/photo_match/widget.dart';
import 'package:byebyesleep/challenges/registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Camera returning queued "photos" (single bytes standing for scenes).
class FakeCamera implements PhotoCamera {
  FakeCamera(this.shots);

  final List<int> shots;

  @override
  Future<void> init() async {}

  @override
  Widget preview() => const SizedBox(key: Key('fake-preview'), height: 10);

  @override
  Future<Uint8List> capture() async => Uint8List.fromList([shots.removeAt(0)]);

  @override
  Future<void> dispose() async {}
}

class MemoryPhotoStore implements PhotoStore {
  final files = <String, Uint8List>{};

  @override
  Future<String> save(Uint8List bytes) async {
    final path = 'mem/${files.length}.jpg';
    files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List?> load(String path) async => files[path];
}

/// Same scene byte → 0.95, otherwise 0.4.
Future<double> fakeScore(Uint8List a, Uint8List b) async =>
    a.single == b.single ? 0.95 : 0.4;

Widget host(FakeCamera camera, MemoryPhotoStore store, Widget child) =>
    ProviderScope(
      overrides: [
        photoCameraProvider.overrideWithValue(() => camera),
        photoStoreProvider.overrideWithValue(store),
        photoScorerProvider.overrideWithValue(fakeScore),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  late MemoryPhotoStore store;
  late Map<String, Object?> params;

  setUp(() async {
    store = MemoryPhotoStore();
    params = {
      'photos': [
        await store.save(Uint8List.fromList([1])),
        await store.save(Uint8List.fromList([1])),
      ],
      'minMatch': 0.9,
    };
  });

  Future<int> run(
    WidgetTester tester,
    List<int> shots, {
    bool check = true,
  }) async {
    var passed = 0;
    await tester.pumpWidget(
      host(
        FakeCamera(shots),
        store,
        PhotoMatchChallenge(
          args: ChallengeArgs(
            difficulty: 2,
            random: Random(1),
            onPassed: () => passed++,
            params: params,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (!check) return passed;
    await tester.tap(find.byKey(const Key('photo-check')));
    await tester.pumpAndSettle();
    return passed;
  }

  testWidgets('photoChallenge_matchPasses', (tester) async {
    expect(await run(tester, [1]), 1);
  });

  testWidgets('photoChallenge_mismatchShowsScore', (tester) async {
    expect(await run(tester, [2]), 0);
    expect(find.textContaining('40%'), findsOneWidget);
  });

  Future<Map<String, Object?>?> runSetup(
    WidgetTester tester,
    List<int> shots, {
    bool save = true,
  }) async {
    Map<String, Object?>? saved;
    await tester.pumpWidget(
      host(
        FakeCamera(shots),
        store,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await setupPhoto(context, const {}),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-take')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('photo-take')));
    await tester.pumpAndSettle();
    if (save) {
      await tester.tap(find.byKey(const Key('setup-save')));
      await tester.pumpAndSettle();
    }
    return saved;
  }

  testWidgets('photoSetup_warnsWhenReferencesDiffer', (tester) async {
    await runSetup(tester, [1, 2], save: false);
    expect(find.byKey(const Key('photo-warning')), findsOneWidget);
  });

  testWidgets('photoSetup_savesParams', (tester) async {
    final saved = await runSetup(tester, [3, 3]);
    expect(saved!['minMatch'], defaultPhotoThreshold);
    expect(saved['photos'], hasLength(2));
    expect(find.byKey(const Key('photo-warning')), findsNothing);
  });

  test('photo_isSetUpNeedsFiles', () async {
    final dir = await Directory.systemTemp.createTemp('photos');
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1]);
    final b = File('${dir.path}/b.jpg')..writeAsBytesSync([1]);
    final def = definitionFor(ChallengeId.photoMatch);
    expect(
      def.isSetUp({
        'photos': [a.path, b.path],
        'minMatch': 0.9,
      }),
      isTrue,
    );
    b.deleteSync();
    expect(
      def.isSetUp({
        'photos': [a.path, b.path],
        'minMatch': 0.9,
      }),
      isFalse,
    );
    expect(def.isSetUp(const {}), isFalse);
  });

  testWidgets('photo_showsTheReferencePhoto', (tester) async {
    await run(tester, [], check: false);
    expect(find.byKey(const Key('photo-reference')), findsOneWidget);
    await tester.tap(find.byKey(const Key('photo-reference')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('photo-reference-large')), findsOneWidget);
  });

  testWidgets('photo_ignoresTheOldStricterSetting', (tester) async {
    // Alarms saved before the new scoring kept 'threshold': 0.9 on the
    // old scale, which no retake could reach.
    params = {'photos': params['photos'], 'threshold': 0.99};
    expect(await run(tester, [1]), 1);
  });
}
