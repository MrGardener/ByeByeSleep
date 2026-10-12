# Phase 3A — Sensor Quest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A playable Sensor Quest game (spec §7): seven worlds that unlock in order, Battery Oracle included, plus a Practice mode that runs any alarm challenge on demand.

**Architecture:** Each world is a pure Dart game rule (fed sensor values and time, returns progress), with a thin widget on top, like the challenges. `lib/game/` holds the world list, the unlock rule, saved progress (a JSON file in the app documents directory), and the screens. Barometer and proximity are added to the existing native `byebyesleep/sensors` channel.

**Tech Stack:** Flutter / Riverpod 3, sensors_plus (motion), battery_plus, nfc_manager, and Kotlin `SensorManager` for pressure and proximity.

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md` (§7 Sensor Quest, §8 Testing)

## Global Constraints

- Battery Oracle: the player enters a whole number from 0 to 100. The real level is read **at submit time**. A guess passes when `|guess − actual| ≤ 25` (9 % → 0–34 accepted). The status bar is hidden during the level (immersive mode) and restored afterwards.
- A world whose sensor this phone lacks shows "Not on this phone" and **does not block** later worlds.
- No new pub dependencies.
- Pure rules have no Flutter imports. Time is passed in (`Duration`), never read from a clock.
- min Android SDK is 29. Pixel 10 Pro is the test phone.

## Rulings (taken without owner review; the owner delegated these calls)

- **Phase 3A worlds:** Battery Oracle, Labyrinth, Compass Temple, Solar Garden, Ghost Hide, Sky Tower, Rune Hunt. Phase 3B gets Color Safari, Bomb Defuse, Choir Cave, Beacon Seek, Pulse Run and the Tier A alarm challenges. These need the microphone, ML Kit, BLE, PPG or new haptics plumbing, and each is its own risk. Cost if wrong: the order changes, nothing is thrown away.
- **No Flame.** Spec §3.1 names Flame for game rendering. The maze already renders well with CustomPaint, and the worlds are simple meters and pictures. Cost if wrong: worlds get re-skinned later.
- **Progress is saved to `quest.json` via path_provider**, which is already a dependency, instead of adding shared_preferences.
- **Sky Tower target is 0.30 hPa below the starting pressure**, about one floor (3 m ≈ 0.36 hPa). It must hold for 2 s on a 1 s moving average, so a door slam or the AC cannot pass it.

## Review Focus

1. Battery Oracle tolerance edges (0, 100, ±25 exactly, ±26) and "read at submit" (the level changes between opening and submitting).
2. Immersive mode is restored if the player leaves the level any way (back, pass, app paused).
3. A world whose stream never emits (sensor missing at runtime) shows "Not on this phone" instead of hanging.
4. Proximity on Pixel reports only near/far (0 or maxRange): the near test is `distance < maxRange`.
5. Progress file missing or corrupt → start fresh, never crash.

---

### Task 1: Quest model, unlock rule, saved progress

**Files:**
- Create: `lib/game/quest.dart` (pure), `lib/game/progress_store.dart`
- Test: `test/game/quest_test.dart`, `test/game/progress_store_test.dart`

**Interfaces:**
- Produces: `enum World { batteryOracle, labyrinth, compassTemple, solarGarden, ghostHide, skyTower, runeHunt }` in this order, with `String get title`, `String get blurb`, `Set<SensorKind> get requires`.
- Produces: `enum WorldStatus { locked, open, completed, unsupported }` and `WorldStatus worldStatus(World w, Set<World> completed, Set<SensorKind> caps)`. A world is `unsupported` when `caps` lacks any of its requirements. It is `completed` when in `completed`. It is `open` when every earlier world is completed or unsupported, and `locked` otherwise.
- Produces: `abstract class ProgressStore { Future<Set<World>> load(); Future<void> save(Set<World>); }`, `FileProgressStore(Future<Directory> Function() dir)` writing `{"completed":["batteryOracle",…]}`, plus `questProgressProvider` (an `AsyncNotifier<Set<World>>` with `complete(World)`).

- [ ] Tests: the first world is open on a fresh start. The second is locked until the first is completed. An unsupported middle world does not block the next one. Unknown names in the file are ignored. A missing file or invalid JSON loads `{}`. A save→load round trip works.
- [ ] Run `flutter test test/game` → FAIL (missing). Implement. Run → PASS. Commit `feat(game): quest model and saved progress`.

### Task 2: Battery Oracle

**Files:**
- Create: `lib/game/worlds/battery_oracle.dart`
- Modify: `lib/challenges/core/battery.dart` (add `BatteryLevelSource { Future<int> level(); }`, `batteryLevelProvider`)
- Test: `test/game/battery_oracle_test.dart`

**Interfaces:**
- Produces: `bool oracleAccepts(int guess, int actual)` and `({int low, int high}) oracleRange(int actual)`.
- Produces: `BatteryOracleWorld({required VoidCallback onPassed})`.

- [ ] Tests (pure): `oracleRange(9) == (low: 0, high: 34)`, `oracleRange(90) == (low: 65, high: 100)`. `oracleAccepts(34, 9)` is true and `oracleAccepts(35, 9)` is false. `oracleAccepts(75, 100)` is true and `oracleAccepts(74, 100)` is false.
- [ ] Widget tests:
  - Typing 150 shows an error and does not read the battery.
  - The level is read on submit: the fake returns 50, then 80 after the widget is built, and a guess of 70 passes.
  - A miss shows the real level and range, offers "Try again", and does not call `onPassed`.
  - Immersive mode is entered on init and restored on dispose (record `SystemChrome` calls via `TestDefaultBinaryMessengerBinding` on `SystemChannels.platform`).
- [ ] Commit `feat(game): Battery Oracle world`.

### Task 3: Barometer and proximity

**Files:**
- Modify: `android/.../alarm/EnvSensorsChannel.kt` (add `TYPE_PRESSURE` → event channel `byebyesleep/pressure` in hPa, and `TYPE_PROXIMITY` → `byebyesleep/proximity` emitting `true` when `values[0] < maximumRange`; `available` adds `"barometer"` and `"proximity"`)
- Modify: `lib/challenges/core/types.dart` (`SensorKind.barometer`, `SensorKind.proximity`), `lib/challenges/core/env_sensors.dart` (`Stream<double> get pressure`, `Stream<bool> get proximityNear`, mapped in `available()`), `test/support/fake_env_sensors.dart`
- Test: `test/challenges/env_sensors_test.dart` (the mock channel's `available` returns the new names and maps to the new kinds)

- [ ] Commit `feat(sensors): barometer and proximity streams`.

### Task 4: Sensor worlds (pure rule + widget each)

**Files:** `lib/game/worlds/{labyrinth,compass_temple,solar_garden,ghost_hide,sky_tower,rune_hunt}.dart`; tests in `test/game/worlds_test.dart`.

Every widget takes `onPassed` and shows a progress bar. A world whose stream gives no value within 3 s calls `onUnavailable`.

- **Labyrinth:** tilt maze levels 2, 3 and 4 in a row (reuse `TiltMazeChallenge`). It passes after the third.
- **Compass Temple:** `CompassTrial(List<double> targets)` with `update(double heading, Duration now) → ChallengeProgress`. Each target must be held within ±15° (use `headingOk`) for 2 s, and leaving resets that target's timer. There are 4 random targets at least 60° apart. Heading comes from `headingDegrees(accel, mag)`.
  - Test: each target held for 2 s passes. Leaving at 1.9 s resets the timer. 350° counts as within 15° of 5°.
- **Solar Garden:** `SolarGarden.update(double lux, Duration now)`. Growth accumulates while `lux ≥ 150` and drops at half speed below that (floor 0). It passes at 10 s of growth.
  - Test: 10 s at 200 lux passes. 6 s light, 4 s dark, then 8 s light passes at the right moment.
- **Ghost Hide:** `GhostHide(Random)` holds a schedule of 5 ghost visits. Each visit gives a 1 s warning and then a 2 s look. The player must be `near` (covered) during the whole look; during a look `update(bool near, Duration now)` with far fails the visit and restarts it. The player must be uncovered (far) between visits, or the next visit does not start. It passes after 5 survived visits.
  - Test: a covered player passes after 5 visits. Uncovered during a look restarts the visit. Covered the whole time does not progress.
- **Sky Tower:** `SkyTower.update(double hPa, Duration now)`. The baseline is the mean of the first 3 s. It passes when the 1 s moving average stays ≤ baseline − 0.30 for 2 s.
  - Test: a slow drop of 0.35 passes. A 0.5 spike lasting 0.5 s does not.
- **Rune Hunt:** `RuneHunt(int needed = 3).add(String tagId)`. It counts distinct tags, so the same tag twice counts once.
  - Test: three distinct tags pass; repeats don't count.

- [ ] One commit per world, `feat(game): <world>`.

### Task 5: Quest and Practice screens

**Files:**
- Create: `lib/game/quest_screen.dart` (one card per world with its status icon; tapping an open or completed world plays it), `lib/game/world_screen.dart` (runs the world; on pass marks it complete, then "World complete!" → back), `lib/game/practice_screen.dart` (lists every `ChallengeId` with a difficulty slider 1–5; a challenge with `setup` runs its setup first; on pass shows "Passed")
- Modify: `lib/app/routes.dart` (`/quest`, `/practice`), `lib/alarm/ui/alarm_list_screen.dart` (app bar: "Sensor Quest" icon `Icons.sports_esports`, "Practice" icon `Icons.fitness_center`)
- Test: `test/game/quest_screen_test.dart`. On a fresh start Battery Oracle is open and Labyrinth locked. Passing Battery Oracle opens Labyrinth and saves it. Without a barometer, Sky Tower shows "Not on this phone". Practice runs Broken calculator and shows Passed.

- [ ] Commit `feat(game): quest and practice screens`.

### Task 6: Docs

- [ ] Add rows to `docs/testing/pixel-checklist.md` for each world and for Practice. Add a Sensor Quest section to the README. Commit `docs: Sensor Quest`.
