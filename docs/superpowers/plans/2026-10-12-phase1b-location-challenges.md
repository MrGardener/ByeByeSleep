# Phase 1B — Location Challenges, Setup & Safety Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the challenges that get the user out of bed — lights on, walk N steps, photo match, NFC sticker, barcode, charger — with per-stage setup, a one-tap "wake-up routine", pre-flight checks (on save and every evening), biometric protection for weakening an imminent alarm, and tilt-maze level 5.

**Architecture:** Same pattern as 1A: pure detectors + widgets per challenge, registered in `lib/challenges/registry.dart`. Hardware sits behind small interfaces with Riverpod providers (light/steps via a native channel; battery, camera, NFC, barcode, biometrics via plugins) so every challenge is widget-tested with fakes. Setup data lives in `StageConfig.params` (already persisted with the alarm). The evening pre-flight check is native (it must run without Flutter) and reads the stage JSON the native store already holds.

**Tech Stack:** Flutter 3.47.7; new plugins `camera ^0.12.1`, `image ^4.12.0`, `mobile_scanner ^7.4.2`, `nfc_manager ^4.2.1`, `battery_plus ^7.1.2`, `local_auth ^3.0.2`, `permission_handler ^13.0.2`; Kotlin `SensorManager` (TYPE_LIGHT, TYPE_STEP_DETECTOR).

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md` (§2.2, §4.2, §4.3, §4.4 level 5, §4.5 Tier S rows `lights_on`, `walk_steps`, `photo_match`, `nfc_tag`, `barcode`, `charger`, §6.1, §6.5).

## Global Constraints

- Detectors stay pure (`dart:*` + `lib/challenges/core/types.dart` only); photo similarity may import `package:image` (pure Dart).
- Setup params keys (persisted, never rename): lights `lux` (double); walk `steps` (int); photo `photos` (List<String> of 2 file paths), `threshold` (double); NFC `tagId` (uppercase hex String); barcode `code` (String).
- Lights pass: lux ≥ max(10, 0.5 × calibrated `lux`), default threshold 30 lux when uncalibrated, held continuously **2 s**.
- Walk pass: counted steps ≥ ceil(0.8 × `steps`), minimum 10 (default `steps` 20 when uncalibrated); a step only counts if it arrives **0.25 s or more** after the previous counted step (shaking is faster).
- Photo match: score 0.0–1.0; default threshold **0.90**, adjustable **0.75–0.95**; setup takes **two** reference photos and warns when their mutual score < threshold + 0.03; pass when score ≥ threshold against either reference.
- Charger pass: a transition from not plugged to plugged *during* the challenge (if plugged at start, it must be unplugged first).
- Biometric/device-credential confirmation is required to disable, delete, or change the time of an enabled alarm whose next ring is within **30 min**; devices without any lock method skip it.
- Evening pre-flight notification at **21:00** local time daily.
- Maze level 5: maze size 11; the ball is frozen unless the phone's heading is within **±15°** of a target heading that drifts at **10°/s** (sine sweep ±60° around the starting heading).
- Android permissions added: `CAMERA`, `ACTIVITY_RECOGNITION`, `NFC`, `USE_BIOMETRIC`; `uses-feature` camera and nfc with `required="false"`. iOS Info.plist strings for camera, NFC, Face ID and motion.
- Commits on `claude/charming-thompson-037p4u`; every commit passes format, analyze, `flutter test`, Kotlin JVM tests.

## Review Focus

1. **A location stage without its setup** (alarm saved before setup, reference photo deleted, NFC sticker never registered) — at ring time the stage must not become impossible: it is substituted by `brokenCalculator` at the same difficulty. Pinned by `resolveStage_missingSetupSubstitutes` (Task 1).
2. **Lights challenge in a room that is already bright** (morning sun) — passes after 2 s; the user is not stuck. Pinned by `lights_alreadyBrightPassesAfterHold` (Task 3).
3. **Phone shaken in the hand to fake steps** — steps faster than 0.25 s apart don't count. Pinned by `walk_shakingDoesNotCount` (Task 4).
4. **Phone already on the bedside charger when the alarm rings** — must be unplugged and plugged in again. Pinned by `charger_pluggedAtStartNeedsReplug` (Task 5).
5. **Dark morning photo vs. lights-on reference** — brightness changes alone don't fail a match; a different place does. Pinned by `similarity_brightnessShiftStillMatches` and `similarity_differentSceneFails` (Task 6).

---

### Task 1: Challenge params, setup hook, new sensors in the registry

**Files:** Modify `lib/challenges/core/challenge_id.dart`, `lib/challenges/core/types.dart`, `lib/challenges/core/challenge.dart`, `lib/challenges/registry.dart`, `lib/ringing/stage_runner.dart`, `lib/alarm/ui/stage_editor.dart` (practice passes params); Test `test/challenges/registry_test.dart`

**Interfaces:**
- Produces:
  - `ChallengeId` gains (append only): `lightsOn, walkSteps, photoMatch, nfcTag, barcode, charger`.
  - `SensorKind` gains `light, stepDetector, magnetometer, camera, nfc, battery`.
  - `ChallengeArgs` gains `final Map<String, Object?> params` (default `const {}`); `StageRunner` and `PracticeScreen` pass `stage.params`.
  - `ChallengeDefinition` gains `final bool Function(Map<String, Object?> params) isSetUp` (default: always true) and `final Future<Map<String, Object?>?> Function(BuildContext context, Map<String, Object?> current)? setup` (null = no setup).
  - `resolveStage(StageConfig, Set<SensorKind>)` additionally substitutes `brokenCalculator` (same difficulty) when `!isSetUp(params)`; maze levels ≥ 4 whose sensors are missing fall back to level 3 (fixes deferred minor M6).
  - Placeholder definitions for the six new ids (title + instructions + requires) so the registry is total; each later task replaces its `build`/`setup`/`isSetUp`.
  Requires: lightsOn {light}, walkSteps {stepDetector}, photoMatch {camera}, nfcTag {nfc}, barcode {camera}, charger {battery}; tiltMaze d5 {accelerometer, magnetometer}.
- [ ] **Step 1: Failing tests** — `resolveStage_missingSetupSubstitutes` (photoMatch with `params: {}` → brokenCalculator, same difficulty; with photos+threshold and {camera} → unchanged), `maze5_withoutMagnetometer_isLevel3`, `maze4_withoutGyro_isLevel3` (kept), `everyNewChallengeHasDefinition`.
- [ ] **Step 2–4:** RED → implement → GREEN (whole suite).
- [ ] **Step 5: Commit** `feat(challenges): params, setup hook and new sensor kinds`

### Task 2: Native light & step sensors, new permissions

**Files:**
- Create: `android/.../alarm/EnvSensorsChannel.kt` (`byebyesleep/sensors` method channel + `byebyesleep/light`, `byebyesleep/steps` event channels), `lib/challenges/core/env_sensors.dart`, `test/support/fake_env_sensors.dart`
- Modify: `MainActivity.kt`, `RingActivity.kt` (register channel), `Permissions.kt` (+ `activityRecognition`, `camera`), `AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/alarm/alarm_platform.dart` (`PermissionKind.activityRecognition, camera`), `lib/alarm/ui/preflight_banner.dart` (labels)
- Test: `test/challenges/env_sensors_test.dart`, extend `test/alarm/alarm_platform_test.dart`

**Interfaces:**
- Produces:
  ```dart
  abstract class EnvSensorSource {
    Stream<double> get lux;            // ambient light, lux
    Stream<Duration> get steps;        // one event per detected step, monotonic timestamp
    Future<Set<SensorKind>> available(); // subset of {light, stepDetector}
    Future<bool> requestActivityPermission();
  }
  class ChannelEnvSensorSource implements EnvSensorSource
  final envSensorProvider = Provider<EnvSensorSource>(...);
  ```
  Native `available` returns `["light","stepDetector"]` from `SensorManager.getDefaultSensor`; step events carry `event.timestamp` (ns) → Dart `Duration(microseconds: ns ~/ 1000)`. Missing plugin (iOS) → empty set, empty streams.
  `requestActivityPermission` uses `permission_handler` (`Permission.activityRecognition`).
- [ ] **Step 1: Failing tests** — `channel source maps lux and step events` (mock EventChannel via `TestDefaultBinaryMessengerBinding` → values arrive), `missing plugin → no sensors`, `permissions include activityRecognition and camera`.
- [ ] **Steps 2–4.** CI build + emulator smoke green.
- [ ] **Step 5: Commit** `feat(sensors): native light and step sensors, camera/activity permissions`

### Task 3: Lights on

**Files:** Create `lib/challenges/lights_on/detector.dart`, `widget.dart`, `setup.dart`; Test `test/challenges/lights_on_test.dart`

**Interfaces:**
- Produces: `class LightsDetector { LightsDetector({double? calibratedLux}); double get threshold; ChallengeProgress onLux(double lux, Duration t); }` — progress = held time / 2 s while above threshold; drops to 0 when below.
  Widget: black screen, dim "Turn on the light" text, progress ring; `Key('lights-level')` shows current lux. Setup: live lux reading, "Turn the light on, then tap Save" → `{'lux': current}`.
- [ ] **Step 1: Failing tests** — `lights_thresholdFromCalibration` (cal 200 → 100; cal 8 → 10; none → 30), `lights_alreadyBrightPassesAfterHold` (lux 500 from t=0 → passed at 2.0 s, not at 1.9 s), `lights_dippingResetsHold`, widget `lightsWidget_passesWithFakeLux`, `lightsSetup_savesCurrentLux`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): lights on`

### Task 4: Walk steps

**Files:** Create `lib/challenges/walk_steps/detector.dart`, `widget.dart`, `setup.dart`; Test `test/challenges/walk_steps_test.dart`

**Interfaces:**
- Produces: `class WalkDetector { WalkDetector({int? calibratedSteps}); int get required; int get counted; ChallengeProgress onStep(Duration t); }`.
  Widget: big counter "N of M steps", asks for activity permission if needed (denied → challenge shows "Allow physical activity" button; still denied after 30 s → `onPassed` is NOT called; the 5-min fallback rule covers it).
  Setup: "Stand at your bed, tap Start, walk to the spot, tap Done" → `{'steps': counted}` (minimum 5 to save).
- [ ] **Step 1: Failing tests** — `walk_requiredIs80Percent` (25 → 20; 5 → 10; none → 16), `walk_shakingDoesNotCount` (steps every 0.1 s → counted grows at most every 0.25 s), `walk_normalPacePasses` (0.6 s apart), widget `walkWidget_passesWithFakeSteps`, `walkSetup_countsSteps`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): walk steps`

### Task 5: Charger

**Files:** Create `lib/challenges/charger/detector.dart`, `widget.dart`, `lib/challenges/core/battery.dart`; Test `test/challenges/charger_test.dart`

**Interfaces:**
- Produces: `abstract class ChargeSource { Future<bool> isPlugged(); Stream<bool> get plugged; }` (battery_plus: charging/full = plugged), `chargeSourceProvider`; `class ChargerDetector { ChargerDetector({required bool pluggedAtStart}); bool get needsUnplug; ChallengeProgress onPlugged(bool plugged); }`.
- [ ] **Step 1: Failing tests** — `charger_plugInPasses`, `charger_pluggedAtStartNeedsReplug` (true → no pass; false → still no pass; true → pass), widget `chargerWidget_textAsksToUnplugFirst`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): charger`

### Task 6: Photo similarity (pure)

**Files:** Create `lib/challenges/photo_match/similarity.dart`; Test `test/challenges/photo_similarity_test.dart`

**Interfaces:**
- Produces: `double photoSimilarity(Uint8List a, Uint8List b)` — decode (JPEG/PNG), resize to 64×64; score = 0.5 × histogram correlation (hue 18 × saturation 4 bins, value ignored, Pearson correlation mapped to 0–1) + 0.5 × edge correlation (Sobel magnitude on brightness-normalised grayscale, Pearson mapped to 0–1). Undecodable input → 0.
- [ ] **Step 1: Failing tests** (synthetic images built with `package:image`: scene A = coloured rectangles/circles on a gradient, scene B = different shapes/colours):
  - `similarity_identicalIsNearOne` (≥ 0.99)
  - `similarity_brightnessShiftStillMatches` (A × 0.6 brightness ≥ 0.90)
  - `similarity_smallShiftStillMatches` (A translated 2 px ≥ 0.85)
  - `similarity_differentSceneFails` (A vs B < 0.75)
  - `similarity_garbageIsZero`
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(photo): image similarity score`

### Task 7: Photo match challenge + setup

**Files:** Create `lib/challenges/photo_match/widget.dart`, `setup.dart`, `lib/challenges/core/camera.dart`; Test `test/challenges/photo_match_test.dart`

**Interfaces:**
- Consumes: `photoSimilarity`.
- Produces: `abstract class PhotoCamera { Widget preview(); Future<Uint8List> capture(); Future<void> dispose(); }`, `final photoCameraProvider = Provider<PhotoCamera Function()>(...)` (real: back camera via `camera`, `ResolutionPreset.medium`); photos stored under `<app documents>/photos/<millis>.jpg` via `photoStoreProvider` (`Future<String> save(Uint8List)`, `Future<Uint8List?> load(String path)`).
  Challenge: live preview + "Check" button → score vs both references → pass if ≥ threshold; else shows "Not quite — 72% match" (`Key('photo-score')`). Setup: take photo 1 and 2, shows mutual score, warns (`Key('photo-warning')`) if < threshold + 0.03, threshold slider 0.75–0.95, Save → `{'photos': [p1, p2], 'threshold': t}`. `isSetUp`: both files exist.
- [ ] **Step 1: Failing tests** with a fake camera returning chosen image bytes: `photoChallenge_matchPasses`, `photoChallenge_mismatchShowsScore`, `photoSetup_warnsWhenReferencesDiffer`, `photoSetup_savesParams`, `photo_isSetUpNeedsFiles`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): photo match`

### Task 8: NFC sticker

**Files:** Create `lib/challenges/nfc_tag/widget.dart`, `setup.dart`, `lib/challenges/core/nfc.dart`; Test `test/challenges/nfc_tag_test.dart`

**Interfaces:**
- Produces: `abstract class NfcReader { Future<bool> isAvailable(); Stream<String> tagIds(); Future<void> stop(); }` (nfc_manager session; id = identifier bytes as uppercase hex), `nfcReaderProvider`. Challenge passes on a tag whose id == params `tagId`; wrong tag shows "That's a different sticker". Setup: "Hold the phone to your sticker" → `{'tagId': id}`.
- [ ] **Step 1: Failing tests** — `nfc_rightTagPasses`, `nfc_wrongTagShowsMessage`, `nfcSetup_savesTagId`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): NFC sticker`

### Task 9: Barcode

**Files:** Create `lib/challenges/barcode/widget.dart`, `setup.dart`, `lib/challenges/core/barcode_scanner.dart`; Test `test/challenges/barcode_test.dart`

**Interfaces:**
- Produces: `typedef BarcodeScannerBuilder = Widget Function(ValueChanged<String> onCode);` `barcodeScannerProvider` (real: `MobileScanner(onDetect: ...)` first raw value). Same pass/setup pattern as NFC with params `code`.
- [ ] **Step 1: Failing tests** — `barcode_rightCodePasses`, `barcode_wrongCodeShowsMessage`, `barcodeSetup_savesCode`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): barcode`

### Task 10: Setup in the stage editor + wake-up routine

**Files:** Modify `lib/alarm/ui/stage_editor.dart`; Test extend `test/alarm/ui/stage_editor_test.dart`

**Interfaces:**
- Produces: rows of challenges with `setup != null` show a "Set up" button (`Key('setup-stage-<i>')`) and, when `!isSetUp`, a warning chip `Key('needs-setup-<i>')` "Needs setup". A "Use wake-up routine" button (`Key('use-routine')`) replaces the stages with: `lightsOn d2`, `walkSteps d2`, `photoMatch d2`, `tiltMaze d2`, `brokenCalculator d2` (spec §4.2: Lights → Move → Brain → Proof), keeping params of matching existing stages.
- [ ] **Step 1: Failing tests** — `editor_showsNeedsSetupForPhoto`, `editor_setupStoresParams` (fake setup returns params → saved alarm has them), `editor_routineTemplate`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(ui): stage setup and wake-up routine`

### Task 11: Pre-flight on save and every evening

**Files:**
- Create: `lib/alarm/preflight.dart`, `android/.../alarm/Preflight.kt` (pure), `android/.../alarm/PreflightReceiver.kt`
- Modify: `alarm_edit_screen.dart` (dialog before save), `AlarmChannel`/`MainActivity` (schedule daily check on app start), `BootReceiver` (reschedule), manifest
- Test: `test/alarm/preflight_test.dart`, `android/.../PreflightTest.kt`

**Interfaces:**
- Produces: Dart `List<String> preflightProblems(Alarm alarm, PermissionStatus permissions)` — one human sentence per problem (missing permission; "Stage 3 (Photo match) needs setup"). On Save, if problems exist: dialog `Key('preflight-dialog')` with "Save anyway" / "Fix".
  Kotlin `object Preflight { fun problems(specs: List<AlarmSpec>, permissionsOk: Boolean, nowMs: Long, zone): List<String> }` — enabled alarms ringing in the next 24 h whose `stagesJson` has a setup-needing challenge (`photoMatch` without `photos`, `nfcTag` without `tagId`, `barcode` without `code`), plus "permissions missing". `PreflightReceiver` (inexact `AlarmManager.setAndAllowWhileIdle` daily at 21:00) posts a notification "Tomorrow's alarm may not work — tap to fix" when problems exist.
- [ ] **Step 1: Failing tests** — Dart `preflight_listsMissingSetupAndPermissions`, `editScreen_showsPreflightDialog`; Kotlin `problems_flagsPhotoWithoutSetup`, `problems_ignoresAlarmsBeyond24h`, `problems_emptyWhenAllGood`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(preflight): checks on save and every evening`

### Task 12: Biometric protection

**Files:** Create `lib/alarm/guard.dart`; Modify `alarm_list_screen.dart`, `alarm_edit_screen.dart`, `MainActivity.kt` (extend `FlutterFragmentActivity`, required by `local_auth`); Test `test/alarm/guard_test.dart`

**Interfaces:**
- Produces: `abstract class Authenticator { Future<bool> confirm(String reason); }` (`local_auth`, `biometricOnly: false`; returns true when the device has no lock method), `authenticatorProvider`; `DateTime? nextRing(Alarm a, DateTime now)`; `bool needsGuard(Alarm a, DateTime now)` (enabled and next ring within 30 min). Switch-off, swipe-delete and time change on a guarded alarm call `confirm`; false → no change (swipe restores the row).
- [ ] **Step 1: Failing tests** — `nextRing_repeatAndOneShot`, `needsGuard_within30Minutes`, `toggleOff_guardedAlarm_denied_keepsEnabled`, `toggleOff_unguarded_noPrompt`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(safety): confirm before weakening an imminent alarm`

### Task 13: Tilt maze level 5

**Files:** Modify `lib/challenges/tilt_maze/physics.dart` (`headingDegrees`), `widget.dart`, `lib/challenges/core/motion.dart` (`magnetometer` stream; `available()` includes it); Test extend `test/challenges/tilt_maze_test.dart`

**Interfaces:**
- Produces: `double headingDegrees(Vec3 gravity, Vec3 magnetic)` (tilt-compensated, 0–360, 0 = magnetic north); `double targetHeading(double start, Duration t)` = start + 60·sin(2π·t/12 s) (≤ 10°/s); `bool headingOk(double heading, double target)` (±15°, wrap-around safe). Level 5 freezes the ball (velocity zero, no acceleration) unless `headingOk`.
- [ ] **Step 1: Failing tests** — `heading_flatNorthEastSouth` (flat phone with field along +y → 0°, along +x → 90°), `headingOk_wrapsAround` (359 vs 5 → true), `targetHeading_speedBelow10DegPerSecond`, widget `maze5_frozenWhenOffHeading`.
- [ ] **Steps 2–4.** **Step 5: Commit** `feat(challenges): tilt maze level 5`

### Task 14: Docs and checklist

**Files:** Modify `docs/testing/pixel-checklist.md`, `README.md`
- [ ] **Step 1:** Checklist rows for each new challenge (setup + ring), routine template, pre-flight dialog and 21:00 notification (`adb shell cmd alarm` not needed: set phone clock or wait), biometric prompt within 30 min, maze level 5, NFC/camera permission prompts.
- [ ] **Step 2:** README: list of challenges and what needs setup.
- [ ] **Step 3: Commit + push**; CI and emulator smoke green.

---

## Done when

CI and emulator smoke green; all new challenges pass their widget tests with fakes; owner runs the new checklist rows on the Pixel.

## Decisions taken without owner review (owner was away — please check)

- **Activity recognition replaced by a cadence check** (steps < 0.25 s apart don't count). Google's activity-recognition API reports "walking" only after tens of seconds and needs Play Services; the step detector plus cadence stops shaking without that delay.
- **Lights is its own stage** (black screen until the room is lit), rather than hiding the *next* game while dark.
- **The wake-up routine is opt-in** ("Use wake-up routine" button); new alarms keep the setup-free default four stages so an alarm never needs setup to work.
