import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/stage_config.dart';
import 'package:byebyesleep/alarm/ui/stage_editor.dart';
import 'package:byebyesleep/challenges/core/challenge_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_alarm_platform.dart';
import '../../support/pump_app.dart';

void main() {
  Future<void> openNewAlarm(WidgetTester tester, FakeAlarmPlatform fake) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, fake);
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();
  }

  testWidgets('editor_showsDefaultFourStages', (tester) async {
    await openNewAlarm(tester, FakeAlarmPlatform());
    for (final title in [
      'Orientation hopscotch',
      'Tilt maze',
      'Broken calculator',
      'Colour words',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('editor_cannotRemoveLastStage', (tester) async {
    var changed = <StageConfig>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StageEditor(
            stages: const [StageConfig(ChallengeId.stroopTap)],
            onChanged: (s) => changed = s,
          ),
        ),
      ),
    );
    final remove = tester.widget<IconButton>(
      find.byKey(const Key('remove-stage-0')),
    );
    expect(remove.onPressed, isNull);
    expect(changed, isEmpty);
  });

  testWidgets('editor_addAndSaveStage', (tester) async {
    final fake = FakeAlarmPlatform();
    await openNewAlarm(tester, fake);
    await tester.tap(find.byKey(const Key('add-stage')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pick-stroopTap')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    final stages = fake.stored.values.single.stages;
    expect(stages, hasLength(5));
    expect(stages.last.challenge, ChallengeId.stroopTap);
  });

  testWidgets('editor_removeStageIsSaved', (tester) async {
    final fake = FakeAlarmPlatform();
    await openNewAlarm(tester, fake);
    await tester.tap(find.byKey(const Key('remove-stage-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored.values.single.stages.map((s) => s.challenge), [
      ChallengeId.tiltMaze,
      ChallengeId.brokenCalculator,
      ChallengeId.stroopTap,
    ]);
  });

  testWidgets('editor_difficultyChangeIsSaved', (tester) async {
    final fake = FakeAlarmPlatform(seed: [Alarm(id: 3, hour: 7, minute: 0)]);
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, fake);
    await tester.tap(find.text('07:00'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byKey(const Key('difficulty-1'))).onChanged!(5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();
    expect(fake.stored[3]!.stages[1].difficulty, 5);
  });

  testWidgets('editor_maxSixStages', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StageEditor(
              stages: List.filled(6, const StageConfig(ChallengeId.stroopTap)),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final add = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('add-stage')),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('tryItOpensPracticeAndReturns', (tester) async {
    await openNewAlarm(tester, FakeAlarmPlatform());
    await tester.tap(find.byKey(const Key('try-stage-3'))); // colour words
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stroop-word')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-stage')), findsOneWidget);
  });
}
