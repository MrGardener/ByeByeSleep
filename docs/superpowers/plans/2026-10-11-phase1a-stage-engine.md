# Phase 1A — Stage Engine & First Challenges Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A ringing alarm can only be stopped or snoozed after the user completes its stages (default: four challenges), with a quieter breather between stages, a hint at 2 min, a fallback challenge at 5 min, and a typed-paragraph safety exit after 15 min.

**Architecture:** A pure-Dart `StageEngine` state machine (fake clock in tests) drives the ring screen. Each challenge is a pure detector (no Flutter imports) plus a widget; a registry maps `ChallengeId` → definition. Stage lists are stored with the alarm as an opaque JSON string the native store passes through. Ring progress (stage index, ring start) is kept natively so it survives the ring screen being recreated. Motion comes from `sensors_plus` behind a `MotionSource` interface so tests inject synthetic streams.

**Tech Stack:** Flutter 3.47.7, `flutter_riverpod`, `sensors_plus` (latest), `share_plus` (latest, trace recorder only); Kotlin engine from Phase 0.

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md` (§3.3, §4.1, §4.2, §4.4, §4.5 Tier S rows `tilt_maze`, `broken_calculator`, `stroop_tap`, `orientation_hopscotch`, §6.2–6.4, §8). Phase 1B covers `lights_on`, `walk_steps`, `photo_match`, `nfc_tag`, `barcode`, `charger`, the setup wizard, the pre-flight notification and biometric protection (§6.1, §6.5), and maze level 5.

## Global Constraints

- Detectors live in `lib/challenges/<id>/detector.dart` and import only `dart:*` and `lib/challenges/core/*` — never Flutter or plugins.
- All randomness through an injected `Random` (tests use fixed seeds).
- Difficulty is an int `1..5`.
- Breather default **20 s**, alarm level during breather **0.2** (of full), back to **1.0** when a stage starts.
- Hint after **2 min** on a stage; fallback offered after **5 min**; safety exit after **15 min** of ringing (measured from the first ring, surviving ring-screen recreation).
- Safety exit stops the alarm and never offers snooze.
- Snooze length stays 9 min; Snooze and Stop appear only after the last stage.
- Default stages for an alarm with none configured, in order: `orientationHopscotch` d2, `tiltMaze` d2, `brokenCalculator` d2, `stroopTap` d2.
- Ring screen locks to portrait while shown (orientation hopscotch rotates the phone, not the UI).
- Existing channel contract is extended, not changed: alarm maps gain key `stages` (String, JSON); new methods `getRingProgress`, `saveRingProgress`, `setRingLevel`.
- No network, no analytics.

## Review Focus

1. **Ring screen recreated mid-challenge** (process death, activity relaunch) — user resumes at the same stage and the 15-min safety-exit clock keeps its original start. Pinned by `engine_resumesFromSavedProgress` (Task 3) and `ringProgress_roundTrip` (Task 2).
2. **Device without a gyroscope** — maze level 4 must substitute level 3; a missing accelerometer substitutes `brokenCalculator` at the same difficulty. Pinned by `registry_substitutesWhenSensorMissing` (Task 4).
3. **Alarm saved by an older build (no `stages` key)** — loads with the default four stages, no crash. Pinned by `fromMap_missingStages_usesDefault` (Task 1).
4. **User stuck on a stage** — hint at 2:00, fallback button at 5:00, fallback is a different challenge at the same difficulty. Pinned by `engine_hintAndFallbackTimes` (Task 3).
5. **Rapid repeated taps / wrong answers** — broken calculator and Stroop never pass on wrong input and never crash on input after passing. Pinned by `calculator_ignoresInputAfterPass`, `stroop_wrongResetsStreak` (Tasks 5, 6).

---

### Task 1: Stage model on alarms

**Files:**
- Create: `lib/challenges/core/challenge_id.dart`, `lib/alarm/stage_config.dart`
- Modify: `lib/alarm/alarm.dart` (add `stages`), `android/app/src/main/kotlin/com/mrgardener/byebyesleep/alarm/AlarmSpec.kt` (pass-through `stagesJson`)
- Test: `test/alarm/stage_config_test.dart`, extend `test/alarm/alarm_test.dart`, extend `AlarmSpecTest.kt`

**Interfaces:**
- Produces:
  ```dart
  enum ChallengeId { orientationHopscotch, tiltMaze, brokenCalculator, stroopTap }
  class StageConfig { const StageConfig(this.challenge, {this.difficulty = 2, this.params = const {}});
    final ChallengeId challenge; final int difficulty; final Map<String, Object?> params;
    Map<String, Object?> toJson(); factory StageConfig.fromJson(Map<String, Object?> j); /* value equality */ }
  const List<StageConfig> defaultStages; // Global Constraints order
  String encodeStages(List<StageConfig>); List<StageConfig> decodeStages(String? json); // null/empty/invalid → defaultStages
  ```
  `Alarm` gains `final List<StageConfig> stages` (default `defaultStages`), in `copyWith`, `==`, and `toMap()['stages'] = encodeStages(stages)`; `fromMap` uses `decodeStages(m['stages'] as String?)`. Unknown challenge names in JSON are dropped; if that leaves none → `defaultStages`.
  Kotlin `AlarmSpec` gains `val stagesJson: String = ""`, stored in JSON key `stages`, sent in `toChannelMap()` as `stages`, read by `fromChannelMap`.
- [ ] **Step 1: Failing tests** — `stages_roundTripThroughMap` (custom 2-stage list survives `toMap`/`fromMap`); `fromMap_missingStages_usesDefault`; `decodeStages_unknownChallengeDropped` (`[{"challenge":"teleport"},{"challenge":"stroopTap","difficulty":4}]` → one stroop d4); `decodeStages_invalidJson_usesDefault`; Kotlin `json_roundTrip_keepsStages`, `channelMap_includesStages`, and update `channelMap_roundTrip` key set to include `stages`.
- [ ] **Step 2: Run** `flutter test` and the JVM tests → FAIL.
- [ ] **Step 3: Implement.** **Step 4: Run** → PASS (also existing tests).
- [ ] **Step 5: Commit** `feat(stages): stage list stored with each alarm`

### Task 2: Native ring progress and ring level

**Files:**
- Modify: `AlarmService.kt`, `AlarmChannel.kt`, `lib/alarm/alarm_platform.dart`, `test/support/fake_alarm_platform.dart`
- Create: `android/app/src/main/kotlin/com/mrgardener/byebyesleep/alarm/RingProgress.kt`
- Test: `android/app/src/test/kotlin/.../alarm/RingProgressTest.kt`, extend `test/alarm/alarm_platform_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class RingProgress { const RingProgress({required this.alarmId, required this.stageIndex, required this.startedAtMs}); ... toMap/fromMap }
  // AlarmPlatform additions:
  Future<RingProgress?> getRingProgress();          // null when nothing ringing / unknown
  Future<void> saveRingProgress(RingProgress p);
  Future<void> setRingLevel(double level);          // 0.0–1.0
  ```
  Kotlin: `data class RingProgress(alarmId: Int, stageIndex: Int, startedAtMs: Long)` with `toJson/fromJson`. `AlarmService.ring()` writes `RingProgress(id, 0, now)` to the device-protected `ringing` prefs **only if none is stored** (a redelivered ring keeps progress); `stopRinging()` clears it. Channel `getRingProgress` / `saveRingProgress` read/write the same prefs; `setRingLevel` → `MediaPlayer.setVolume(level, level)` on the running service (static player reference or service intent `ACTION_SET_LEVEL` with float extra — use the intent). Service restart resets level to 1.0. MissingPlugin → `null` / no-op.
  `FakeAlarmPlatform` records `setRingLevel:<level>` and `saveRingProgress:<alarmId>:<stageIndex>` and returns a settable `ringProgress`.
- [ ] **Step 1: Failing tests** — `ringProgress_roundTrip` (Kotlin JSON); Dart `getRingProgress parses map`, `saveRingProgress sends map`, `setRingLevel sends level`, `missing plugin → null`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS; CI build green.
- [ ] **Step 5: Commit** `feat(engine): persist ring progress and control ring level`

### Task 3: StageEngine

**Files:**
- Create: `lib/ringing/stage_engine.dart`
- Test: `test/ringing/stage_engine_test.dart`

**Interfaces:**
- Consumes: `StageConfig`, `RingProgress`.
- Produces:
  ```dart
  sealed class StagePhase {}
  class Running extends StagePhase { final int index; final StageConfig stage; final bool hintVisible; final bool fallbackAvailable; }
  class Breather extends StagePhase { final int nextIndex; final Duration remaining; }
  class Done extends StagePhase {}
  class StageEngine {
    StageEngine({required List<StageConfig> stages, required DateTime ringStartedAt, int startIndex = 0,
                 required DateTime Function() clock, Duration breather = const Duration(seconds: 20)});
    StagePhase get phase;          // recomputed from clock
    bool get safetyExitAvailable;  // clock - ringStartedAt >= 15 min
    double get ringLevel;          // 0.2 in Breather, else 1.0
    void stagePassed();            // Running(i) → Breather(i+1) or Done if last
    void useFallback(ChallengeId replacement); // replaces current stage, same difficulty; resets its timer
    void tick();                   // Breather → Running when remaining hits 0
    int get currentIndex;          // for RingProgress
  }
  ```
  Stage timer starts when a stage enters Running. Breather counts down from `breather`.
- [ ] **Step 1: Failing tests** (fake clock `var now`):
  - `engine_runsStagesWithBreathers` → 2 stages: Running(0) → `stagePassed` → Breather(1, 20s), ringLevel 0.2 → advance 20s + `tick` → Running(1), ringLevel 1.0 → `stagePassed` → Done.
  - `engine_hintAndFallbackTimes` → at 1:59 hint false; 2:00 hint true; 4:59 fallback false; 5:00 fallback true; after `useFallback(stroopTap)` stage is stroop with original difficulty and both flags false.
  - `engine_safetyExitAfter15Minutes` → ringStartedAt = now − 14:59 → false; +1 s → true.
  - `engine_resumesFromSavedProgress` → `startIndex: 2`, ringStartedAt 10 min ago → Running(2); safety exit at +5 min.
  - `engine_singleStage_passGoesStraightToDone` (no breather after last).
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(engine): stage engine with breather, hint, fallback and safety exit`

### Task 4: Challenge core, registry and motion source

**Files:**
- Create: `lib/challenges/core/challenge.dart`, `lib/challenges/core/motion.dart`, `lib/challenges/registry.dart`
- Modify: `pubspec.yaml` (`sensors_plus`)
- Test: `test/challenges/registry_test.dart`, `test/support/fake_motion_source.dart`

**Interfaces:**
- Produces:
  ```dart
  class ChallengeProgress { const ChallengeProgress(this.value, {this.passed = false}); final double value; final bool passed; }
  enum SensorKind { accelerometer, gyroscope }
  class Vec3 { const Vec3(this.x, this.y, this.z); final double x, y, z; }
  abstract class MotionSource { Stream<Vec3> get accelerometer; Stream<Vec3> get gyroscope; Future<Set<SensorKind>> available(); }
  class SensorsPlusMotionSource implements MotionSource // available(): a kind is available if it emits within 1 s
  final motionSourceProvider = Provider<MotionSource>((_) => SensorsPlusMotionSource());
  class ChallengeDefinition { final ChallengeId id; final String title; final String instructions;
    final Set<SensorKind> Function(int difficulty) requires;
    final Widget Function(ChallengeArgs args) build; }
  class ChallengeArgs { final int difficulty; final Random random; final VoidCallback onPassed; }
  ChallengeDefinition definitionFor(ChallengeId id);
  /// Returns the stage to actually run given available sensors (§6.2):
  /// tiltMaze d4 without gyroscope → tiltMaze d3; anything needing a missing accelerometer → brokenCalculator same difficulty.
  StageConfig resolveStage(StageConfig s, Set<SensorKind> available);
  /// Fallback for the 5-min rule: brokenCalculator unless the stage already is one, then stroopTap.
  ChallengeId fallbackFor(ChallengeId current);
  ```
  Requirements: `orientationHopscotch` → {accelerometer}; `tiltMaze` d1 → {}, d2–3 → {accelerometer}, d4 → {accelerometer, gyroscope}; calculator/stroop → {}.
  Until Tasks 5–8 land, `build` for each id may return a placeholder widget; each later task replaces its own.
- [ ] **Step 1: Failing tests** — `registry_substitutesWhenSensorMissing` (maze d4 + {accel} → maze d3; hopscotch d2 + {} → calculator d2; calculator unchanged), `fallbackFor_neverReturnsSameChallenge`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(challenges): challenge core, registry and motion source`

### Task 5: Broken Calculator

**Files:** Create `lib/challenges/broken_calculator/detector.dart`, `widget.dart`; Test `test/challenges/broken_calculator_test.dart`

Widget keys (used by Task 9 tests): problem text `Key('calc-problem')` (e.g. `47 + 25`), buttons `Key('calc-key-<buttonIndex>')` labelled with their current digit, `Key('calc-submit')`, `Key('calc-back')`.

**Interfaces:**
- Produces: `class BrokenCalculatorDetector { BrokenCalculatorDetector({required int difficulty, required Random random});
  String get problem; List<int> get keypad /* 10 digits, order of buttons */; String get entry;
  ChallengeProgress press(int buttonIndex); ChallengeProgress backspace(); ChallengeProgress submit(); }`
  Difficulty → problems to solve / operands: d1: 1 × `a+b` (1–9); d2: 2 × `a+b` (10–99); d3: 2 × `a±b` (10–99, result ≥ 0); d4: 3 × `a×b` (a 10–99, b 2–9); d5: 3 × `a×b+c`.
  Keypad is reshuffled (via `random`) after **every** button press. Wrong submit → new problem, progress unchanged. Progress = solved / required.
- [ ] **Step 1: Failing tests** — `calculator_solvesWithCorrectAnswer` (seeded random; press the buttons whose labels spell the answer → passed after required count), `calculator_keypadReshufflesAfterEachPress`, `calculator_wrongAnswerGivesNewProblem`, `calculator_ignoresInputAfterPass` (no throw, stays passed), widget test `calculatorWidget_callsOnPassed`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(challenges): broken calculator`

### Task 6: Stroop Tap

**Files:** Create `lib/challenges/stroop_tap/detector.dart`, `widget.dart`; Test `test/challenges/stroop_tap_test.dart`

Widget keys: word `Key('stroop-word')` whose `TextStyle.color` is the ink, choice buttons `Key('stroop-<inkName>')`.

**Interfaces:**
- Produces: `enum InkColor { red, green, blue, yellow, purple }`; `class StroopDetector { StroopDetector({required int difficulty, required Random random}); String get word; InkColor get ink; List<InkColor> get choices; ChallengeProgress choose(InkColor c); }`
  Word ≠ ink always. Required streak: d1 3, d2 4, d3 5, d4 6, d5 7. d≥3 shuffles choice order each round; d≥4 uses all 5 colors (else 4). Wrong → streak 0.
- [ ] **Step 1: Failing tests** — `stroop_wordNeverMatchesInk` (200 seeded rounds), `stroop_correctStreakPasses`, `stroop_wrongResetsStreak`, widget `stroopWidget_tapInkColorAdvances`.
- [ ] **Steps 2–4** RED → implement → GREEN. **Step 5: Commit** `feat(challenges): stroop tap`

### Task 7: Orientation Hopscotch

**Files:** Create `lib/challenges/orientation_hopscotch/detector.dart`, `widget.dart`; Test `test/challenges/orientation_hopscotch_test.dart`

**Interfaces:**
- Produces: `enum PhoneOrientation { faceUp, faceDown, portrait, portraitUpsideDown, landscapeLeft, landscapeRight }`;
  `PhoneOrientation? classifyOrientation(Vec3 gravity)` — axis with |value| ≥ 7.0 m/s² wins: +z faceUp, −z faceDown, +y portrait, −y portraitUpsideDown, +x landscapeLeft, −x landscapeRight; else null.
  `class HopscotchDetector { HopscotchDetector({required int difficulty, required Random random}); List<PhoneOrientation> get sequence; int get step; ChallengeProgress onAccel(Vec3 a, Duration t); }`
  Sequence length d1 3 … d5 7, no two consecutive equal. A step counts after holding the target for 300 ms; each step must be reached within (d1 4 s, d2 3 s, d3 2.5 s, d4 2 s, d5 1.5 s) of the previous step, else the sequence restarts at step 0 (same sequence). `t` is a monotonic timestamp.
- [ ] **Step 1: Failing tests** with synthetic gravity traces — `classify_axes`, `hopscotch_holdingEachTargetPasses`, `hopscotch_tooSlowRestarts`, `hopscotch_briefTouchDoesNotCount` (200 ms hold).
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): orientation hopscotch`

### Task 8: Tilt Maze (levels 1–4)

**Files:** Create `lib/challenges/tilt_maze/maze.dart` (generation), `physics.dart`, `widget.dart`; Test `test/challenges/tilt_maze_test.dart`

**Interfaces:**
- Produces: `class Maze { factory Maze.generate(int size, Random r); final int size; bool wall(int cell, Direction d); }` (recursive backtracker; start (0,0), goal (size−1,size−1)); size d1 5, d2 7, d3 9, d4 11.
  `class Ball { Offset pos; Offset vel; }`; `Ball stepBall(Maze m, Ball b, Offset accel, double dt)` — integrates velocity (friction 0.9/step), clamps against walls of the current cell, cell units with radius 0.3.
  Control by difficulty: d1 drag (finger position sets accel toward finger), d2 tilt (`accel = (-ax, ay)` scaled), d3 tilt with both axes inverted, d4 tilt + maze rotated by integrated gyroscope z (ball accel rotated into maze frame). Passed when ball centre is in the goal cell.
- [ ] **Step 1: Failing tests** — `maze_isPerfect` (every cell reachable, seeded, sizes 5–11), `ball_neverCrossesWalls` (10k random steps), `ball_reachesGoalFollowingSolution` (feed accel along BFS path), `invertedControlsFlipAxes`, `rotationTransformsAccel` (90° gyro rotation maps +x to +y).
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): tilt maze levels 1–4`

### Task 9: Ring screen runs the stages

**Files:**
- Create: `lib/ringing/stage_runner.dart`, `lib/ringing/safety_exit.dart`
- Modify: `lib/ringing/ring_screen.dart` (button row only after `Done`; portrait lock)
- Test: `test/ringing/ring_flow_test.dart`, update `test/ringing/ring_screen_test.dart`

**Interfaces:**
- Consumes: `StageEngine`, registry, `AlarmPlatform.getRingProgress/saveRingProgress/setRingLevel`, `motionSourceProvider`.
- Produces: `RingScreen(alarmId:, onFinished:, clock: DateTime.now, random: null)` (test hooks).
  On open: load alarm stages (default if alarm missing), `getRingProgress()` (if its `alarmId` matches use its index/start, else start now and save), resolve stages against `available()` sensors, build engine. Ticks every second. Saves progress on every stage change; calls `setRingLevel(engine.ringLevel)` when it changes. Header shows "Stage i of n" and the challenge title/instructions; hint text after 2 min (`instructions` repeated as "Hint: …"); after 5 min a "Try a different challenge" button → `useFallback(fallbackFor(current))`. Breather shows "Next stage in Ns". `Done` shows Stop + Snooze (Phase 0 behaviour). Safety exit button "I can't finish — emergency stop" after 15 min opens `SafetyExitScreen`: user must type `safetyParagraph` exactly (case-sensitive, trimmed) → `stopRinging()` → `onFinished`. `const safetyParagraph = 'I am awake and I choose to turn off this alarm without finishing my challenges.';`
  `SystemChrome.setPreferredOrientations([portraitUp])` in initState, restore all in dispose.
- [ ] **Step 1: Failing widget tests** (fake platform, fake motion source, fake clock, seeded random, stages = [calculator d1, stroop d1]):
  - `ringFlow_buttonsHiddenUntilDone` → `stop`/`snooze` keys not found at start.
  - `ringFlow_completingStagesShowsStopAndSnooze` → solve calculator (read `calc-problem`, evaluate it, tap the `calc-key-*` buttons whose labels spell the answer, then `calc-submit`), wait breather (advance clock 20 s), solve stroop → buttons visible; `fake.calls` contains `setRingLevel:0.2` then `setRingLevel:1.0`, and `saveRingProgress:<id>:1`.
  - `ringFlow_resumesAtSavedStage` → fake progress index 1 → stroop shown first.
  - `ringFlow_safetyExitAfter15Minutes` → hidden at 14:59; visible at 15:00; wrong text keeps ringing; exact paragraph → `stopRinging` and `onFinished`, never `snooze`.
  - `ringFlow_fallbackAfter5Minutes` → button appears, tapping swaps calculator → stroop.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(ringing): ring screen runs challenge stages`

### Task 10: Stage editor in the alarm screen

**Files:** Create `lib/alarm/ui/stage_editor.dart`; Modify `lib/alarm/ui/alarm_edit_screen.dart`; Test `test/alarm/ui/stage_editor_test.dart`

**Interfaces:**
- Consumes: `StageConfig`, `definitionFor`.
- Produces: `StageEditor({required List<StageConfig> stages, required ValueChanged<List<StageConfig>> onChanged})` — reorderable list (`ReorderableListView`), each row: challenge title, difficulty `Slider` 1–5 (`Key('difficulty-<index>')`), delete (`Key('remove-stage-<index>')`, disabled when one stage left); "Add stage" (`Key('add-stage')`) opens a picker of all `ChallengeId`s; max 6 stages. A "Try it" button per row (`Key('try-stage-<index>')`) opens the challenge full-screen without alarm sound (practice).
- [ ] **Step 1: Failing tests** — `editor_showsDefaultFourStages`, `editor_cannotRemoveLastStage`, `editor_addAndSaveStage` (saved alarm has 5 stages), `editor_difficultyChangeIsSaved`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(ui): stage editor with practice mode`

### Task 11: Trace recorder (developer screen)

**Files:** Create `lib/sensors/trace_recorder_screen.dart`, `lib/sensors/trace.dart`; Modify `lib/alarm/ui/alarm_list_screen.dart` (long-press on app-bar title opens it); `pubspec.yaml` (`share_plus`); Test `test/sensors/trace_test.dart`

**Interfaces:**
- Produces: `class SensorTrace { final List<TraceSample> samples; String toJson(); factory SensorTrace.fromJson(String) }`, `class TraceSample { final String sensor; final int tMicros; final double x, y, z; }`; screen records accelerometer + gyroscope for a chosen 5/10/30 s, then shares the JSON file (`share_plus`). Fixtures recorded on the Pixel go to `test/fixtures/traces/` and can be replayed by `FakeMotionSource.fromTrace`.
- [ ] **Step 1: Failing test** `trace_jsonRoundTrip`, `fakeMotionSource_replaysTraceInOrder`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(dev): sensor trace recorder`

### Task 12: Docs and Pixel checklist

**Files:** Modify `docs/testing/pixel-checklist.md`, `README.md`

- [ ] **Step 1:** Add checklist rows: default 4 stages complete in order with quieter breathers; Stop/Snooze only after last stage; kill the app from adb (`adb shell am kill com.mrgardener.byebyesleep`) mid-stage → reopens at the same stage; leave a stage 5 min → fallback; 15 min → safety exit with paragraph; each challenge's "Try it" works; orientation hopscotch with screen staying portrait.
- [ ] **Step 2:** README "How it works" paragraph on stages + safety exit.
- [ ] **Step 3: Commit** `docs: phase 1A checklist`; push; CI + emulator smoke green (smoke test still taps Stop — update `tool/emulator_smoke.sh` to finish stages via a debug-only intent extra `debug_skip_stages` that makes the debug alarm use zero challenges, so the smoke test keeps checking the native path).

---

## Done when

- CI and emulator smoke test green on the branch.
- On the Pixel: an alarm rings, the four default stages must be completed, then Stop/Snooze appear; checklist rows from Task 12 pass (owner).
