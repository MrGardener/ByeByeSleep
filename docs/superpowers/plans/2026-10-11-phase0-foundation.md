# Phase 0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter app that creates, lists and edits alarms, and an Android alarm engine that rings reliably (reboot, Doze, swipe-away, lock screen) with a plain ring screen offering Stop / Snooze — all built and tested by GitHub Actions.

**Architecture:** Flutter (Dart) owns UI and state; a native Kotlin alarm engine owns scheduling, persistence of schedules, and ringing, because `BootReceiver` must reschedule without Flutter running. They talk over the method channel `byebyesleep/alarm`. Kotlin scheduling logic is pure (no Android imports) behind two interfaces, so it is JVM-unit-tested in CI.

**Tech Stack:** Flutter stable (exact version pinned in `pubspec.yaml`), Dart, `flutter_riverpod`, `flutter_lints`; Kotlin, `java.time`, JUnit 4, `org.json`; GitHub Actions (`subosito/flutter-action@v2`, `actions/checkout@v4`, `actions/setup-java@v4`, `actions/upload-artifact@v4`, `reactivecircus/android-emulator-runner@v2`, `softprops/action-gh-release@v2`).

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md` (§1, §2.1, §3.1–3.2, §5.1, §6.1, §8, §9, §10 Phase 0)

## Global Constraints

- App name `ByeByeSleep`; Android `applicationId` / Dart org: `com.mrgardener.byebyesleep`; Dart package name `byebyesleep`.
- Android `minSdk 29`; `targetSdk`/`compileSdk` = Flutter template default (latest).
- Platforms created: `android`, `ios`. iOS must compile (`flutter build ios --simulator --debug`) but gets no alarm engine in this phase; Dart code must not crash on iOS when the channel is missing (catch `MissingPluginException` → empty list / no-op).
- Method channel name: `byebyesleep/alarm`.
- Weekday encoding everywhere: ISO-8601, `1 = Monday … 7 = Sunday`. Empty `repeatDays` = one-shot alarm.
- Default snooze length: 9 minutes.
- Android permissions: `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SYSTEM_EXEMPTED`, `RECEIVE_BOOT_COMPLETED`, `WAKE_LOCK`, `VIBRATE`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
- Alarm audio on `AudioAttributes.USAGE_ALARM`, `STREAM_ALARM` volume forced to max while ringing.
- No analytics, no network calls, all on device.
- Every commit must pass `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and (from Task 8) `./gradlew testDebugUnitTest` in `android/`.
- Commits end with the session's `Co-Authored-By` / `Claude-Session` trailers; work on branch `claude/charming-thompson-037p4u`.

## Review Focus

1. **Reboot while an alarm is snoozed** — the snooze must still ring after boot (if its time hasn't passed). Pinned by `rescheduleAll_restoresFutureSnooze` (Task 8).
2. **DST transitions** — an alarm at 02:30 on spring-forward day rings at 03:30; on fall-back day 01:30 rings once, at the first occurrence. Pinned by `nextTrigger_springForwardGap` / `nextTrigger_fallBackOverlap` (Task 8).
3. **Repeating alarm after Snooze** — tomorrow's regular occurrence must still be scheduled after a snoozed ring fires. Pinned by `onFired_afterSnooze_schedulesNextRegular` (Task 8).
4. **Missing permissions (notifications / full-screen / battery optimisation)** — the list screen must show what's missing with a button to fix it. Pinned by `preflightBanner_listsMissingPermissions` (Task 6).
5. **Back button / gesture on the ring screen** — must not dismiss the ring screen. Pinned by `ringScreen_backDoesNotPop` (Task 7).

---

### Task 1: Flutter project scaffold

**Files:**
- Create: whole Flutter project at repo root (via `flutter create`), `analysis_options.yaml`, `.gitignore` (template), `README.md` (overwrite)
- Modify: `pubspec.yaml`, `android/app/build.gradle.kts`
- Test: `test/app_smoke_test.dart` (replace template `test/widget_test.dart`)

**Interfaces:**
- Produces: `lib/main.dart` → `void main() => runApp(const ProviderScope(child: ByeByeSleepApp()));` and `lib/app/app.dart` → `class ByeByeSleepApp extends StatelessWidget` (MaterialApp, title `ByeByeSleep`, dark theme by default; home is a placeholder `Scaffold` with text `ByeByeSleep` until Task 6 replaces it).

- [ ] **Step 1: Install Flutter locally** (container has none): clone `https://github.com/flutter/flutter.git -b stable --depth 1` into the scratchpad, add `bin` to `PATH`, run `flutter --version`. Record the exact version (e.g. `3.x.y`).
- [ ] **Step 2: Create the project** in a temp dir and move it to the repo root (repo already has `README.md`, `docs/`):
  `flutter create --org com.mrgardener --project-name byebyesleep --platforms android,ios <tmp>` then copy contents into the repo root.
- [ ] **Step 3: Configure**
  - `pubspec.yaml`: `description: Alarm clock you can't sleep through.`; `environment: sdk: ^<dart version from flutter --version>` and `flutter: <exact version>` (CI reads this); add dependency `flutter_riverpod` (latest), keep `flutter_lints` dev dependency.
  - `android/app/build.gradle.kts`: `minSdk = 29`; `applicationId = "com.mrgardener.byebyesleep"`; `namespace` same.
  - Android label in `AndroidManifest.xml` and iOS `CFBundleDisplayName`: `ByeByeSleep`.
  - `analysis_options.yaml`: include `package:flutter_lints/flutter.yaml`; enable `prefer_const_constructors`, `prefer_final_locals`, `always_declare_return_types`.
  - `README.md`: one paragraph on the app, link to the spec, "Build: `flutter pub get && flutter run`", "CI builds downloadable APKs on every PR".
- [ ] **Step 4: Write smoke test** `test/app_smoke_test.dart`:

```dart
testWidgets('app boots and shows title', (tester) async {
  await tester.pumpWidget(const ProviderScope(child: ByeByeSleepApp()));
  expect(find.text('ByeByeSleep'), findsWidgets);
});
```

- [ ] **Step 5: Verify** — `flutter pub get && dart format --set-exit-if-changed . && flutter analyze && flutter test` → all pass, 0 analyzer issues. `flutter build apk --debug` succeeds (requires Android SDK; if the container cannot install it, CI in Task 2 is the verifier — note that in the commit message).
- [ ] **Step 6: Commit** `chore: scaffold ByeByeSleep Flutter app`

### Task 2: CI workflow and repository hygiene

**Files:**
- Create: `.github/workflows/ci.yml`, `.github/pull_request_template.md`, `.github/dependabot.yml`, `.github/CODEOWNERS`, `.github/ISSUE_TEMPLATE/challenge_idea.yml`, `.github/ISSUE_TEMPLATE/bug_report.yml`

**Interfaces:**
- Produces: CI job names `dart` (ubuntu) and `ios-compile` (macOS) — later tasks add steps to `dart`; branch protection will reference these names.

- [ ] **Step 1: Write `ci.yml`** — triggers: `pull_request`, `push` to `main`, `workflow_dispatch`; `concurrency` cancels superseded runs per ref.
  - Job `dart` (`ubuntu-latest`): checkout → `actions/setup-java@v4` (temurin 17) → `subosito/flutter-action@v2` with `flutter-version-file: pubspec.yaml`, `cache: true` → `flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` → `flutter test --coverage` → `flutter build apk --debug` → `actions/upload-artifact@v4` name `byebyesleep-debug-apk-${{ github.sha }}`, path `build/app/outputs/flutter-apk/app-debug.apk`, retention 14 days.
  - Job `ios-compile` (`macos-latest`): checkout → flutter-action (same pin) → `flutter pub get` → `flutter build ios --simulator --debug`.
- [ ] **Step 2: Hygiene files**
  - PR template sections: `## What`, `## Why`, `## How tested` (checkboxes: CI green, tested on Pixel 10 Pro, N/A), `## Screenshots`.
  - Dependabot: ecosystems `pub` (`/`), `gradle` (`/android`), `github-actions` (`/`), weekly.
  - CODEOWNERS: `* @MrGardener`.
  - Issue forms: challenge idea (fields: name, sensors used, how it wakes you, platforms) and bug report (device, OS version, app version, steps, expected, actual).
- [ ] **Step 3: Validate YAML** locally: `python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/ci.yml .github/dependabot.yml .github/ISSUE_TEMPLATE/*.yml` → no error.
- [ ] **Step 4: Commit and push**, then confirm both CI jobs pass on GitHub (check runs via GitHub MCP tools). Fix and re-push until green.
- [ ] **Step 5: Owner action (not automatable here):** tell the owner to enable branch protection on `main` requiring checks `dart` and `ios-compile`.

### Task 3: Dart `Alarm` model

**Files:**
- Create: `lib/alarm/alarm.dart`
- Test: `test/alarm/alarm_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class Alarm {
    const Alarm({required this.id, required this.hour, required this.minute,
      this.repeatDays = const {}, this.label = '', this.enabled = true});
    final int id; final int hour; final int minute;
    final Set<int> repeatDays; // ISO 1=Mon..7=Sun, empty = one-shot
    final String label; final bool enabled;
    bool get isRepeating;
    Alarm copyWith({int? hour, int? minute, Set<int>? repeatDays, String? label, bool? enabled});
    Map<String, Object?> toMap(); // keys: id, hour, minute, repeatDays (sorted List<int>), label, enabled
    factory Alarm.fromMap(Map<Object?, Object?> m);
    String get timeLabel; // zero-padded 24h "07:05"
  }
  ```
  Value equality (`==`/`hashCode`) over all fields.

- [ ] **Step 1: Write failing tests**

```dart
test('toMap/fromMap round-trips', () {
  const a = Alarm(id: 3, hour: 7, minute: 5, repeatDays: {5, 1}, label: 'Work');
  expect(Alarm.fromMap(a.toMap()), a);
  expect(a.toMap()['repeatDays'], [1, 5]);
});
test('timeLabel is zero padded', () => expect(const Alarm(id: 1, hour: 7, minute: 5).timeLabel, '07:05'));
test('isRepeating', () {
  expect(const Alarm(id: 1, hour: 7, minute: 0).isRepeating, isFalse);
  expect(const Alarm(id: 1, hour: 7, minute: 0, repeatDays: {1}).isRepeating, isTrue);
});
test('constructor rejects invalid values', () {
  expect(() => Alarm(id: 1, hour: 24, minute: 0), throwsA(isA<AssertionError>()));
  expect(() => Alarm(id: 1, hour: 7, minute: 0, repeatDays: {0}), throwsA(isA<AssertionError>()));
});
```

- [ ] **Step 2: Run** `flutter test test/alarm/alarm_test.dart` → FAIL (file missing).
- [ ] **Step 3: Implement** `lib/alarm/alarm.dart` (asserts: `0<=hour<24`, `0<=minute<60`, each day in `1..7`; `fromMap` accepts `List<Object?>` of ints from the channel).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(alarm): add Alarm model`

### Task 4: `AlarmPlatform` and method-channel implementation

**Files:**
- Create: `lib/alarm/alarm_platform.dart`
- Test: `test/alarm/alarm_platform_test.dart`

**Interfaces:**
- Consumes: `Alarm` (Task 3).
- Produces:
  ```dart
  enum PermissionKind { exactAlarm, fullScreenIntent, notifications, ignoreBatteryOptimizations }
  class PermissionStatus {
    const PermissionStatus(this.granted); // Map<PermissionKind,bool>
    final Map<PermissionKind, bool> granted;
    List<PermissionKind> get missing; bool get allGranted;
    static const PermissionStatus unknownAllGranted; // used when channel unavailable
  }
  abstract class AlarmPlatform {
    Future<List<Alarm>> list();
    Future<int?> upsert(Alarm alarm);          // next trigger epoch ms, null if disabled
    Future<void> delete(int id);
    Future<void> stopRinging();
    Future<int> snooze(int id, int minutes);   // snooze trigger epoch ms
    Future<PermissionStatus> permissions();
    Future<void> openSettings(PermissionKind kind);
  }
  class MethodChannelAlarmPlatform implements AlarmPlatform {
    MethodChannelAlarmPlatform([MethodChannel channel = const MethodChannel('byebyesleep/alarm')]);
  }
  ```
  Channel methods (exact names, also used by Task 9): `list` → `List<Map>`; `upsert` (arg: alarm map) → `int?`; `delete` (arg `{id}`); `stopRinging`; `snooze` (args `{id, minutes}`) → `int`; `permissions` → `Map<String,bool>` with keys `exactAlarm`, `fullScreenIntent`, `notifications`, `ignoreBatteryOptimizations`; `openSettings` (arg `{kind: <same key>}`).
  On `MissingPluginException` (iOS in this phase): `list` → `[]`, `permissions` → `unknownAllGranted`, `upsert`/`snooze` → `null`/`0`, others no-op.

- [ ] **Step 1: Write failing tests** using `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler`:

```dart
test('upsert sends alarm map and returns trigger', () async {
  late MethodCall seen;
  mock((call) async { seen = call; return 1760000000000; });
  final r = await platform.upsert(const Alarm(id: 2, hour: 6, minute: 30, repeatDays: {1, 2}));
  expect(seen.method, 'upsert');
  expect((seen.arguments as Map)['repeatDays'], [1, 2]);
  expect(r, 1760000000000);
});
test('list parses maps', () async {
  mock((_) async => [{'id': 1, 'hour': 7, 'minute': 0, 'repeatDays': [], 'label': '', 'enabled': true}]);
  expect(await platform.list(), [const Alarm(id: 1, hour: 7, minute: 0)]);
});
test('permissions reports missing kinds', () async {
  mock((_) async => {'exactAlarm': true, 'fullScreenIntent': false, 'notifications': true, 'ignoreBatteryOptimizations': false});
  expect((await platform.permissions()).missing,
      [PermissionKind.fullScreenIntent, PermissionKind.ignoreBatteryOptimizations]);
});
test('missing plugin degrades gracefully', () async {
  mock(null); // no handler → MissingPluginException
  expect(await platform.list(), isEmpty);
  expect((await platform.permissions()).allGranted, isTrue);
});
```

- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(alarm): add AlarmPlatform method channel`

### Task 5: Alarm list state

**Files:**
- Create: `lib/alarm/alarm_providers.dart`, `test/support/fake_alarm_platform.dart`
- Test: `test/alarm/alarm_list_notifier_test.dart`

**Interfaces:**
- Consumes: `AlarmPlatform`, `Alarm`, `PermissionStatus`.
- Produces:
  ```dart
  final alarmPlatformProvider = Provider<AlarmPlatform>((_) => MethodChannelAlarmPlatform());
  final alarmListProvider = AsyncNotifierProvider<AlarmListNotifier, List<Alarm>>(AlarmListNotifier.new);
  class AlarmListNotifier extends AsyncNotifier<List<Alarm>> {
    Future<Alarm> add({required int hour, required int minute, Set<int> repeatDays, String label}); // id = max(existing)+1, or 1
    Future<void> save(Alarm alarm);        // upsert + replace in state
    Future<void> setEnabled(int id, bool enabled);
    Future<void> remove(int id);
  }
  final permissionStatusProvider = FutureProvider<PermissionStatus>(...); // invalidated by UI on resume
  ```
  State is kept sorted by `(hour, minute, id)`.
  `FakeAlarmPlatform implements AlarmPlatform` — in-memory map, records calls in `List<String> calls`, configurable `PermissionStatus permissionStatus`.

- [ ] **Step 1: Write failing tests** (ProviderContainer with `alarmPlatformProvider.overrideWithValue(fake)`):
  - `add assigns incrementing ids and calls upsert` → ids `1`, `2`; `fake.calls` contains `upsert:1`, `upsert:2`.
  - `state is sorted by time` → add 08:00 then 06:30 → state times `['06:30','08:00']`.
  - `setEnabled(false) upserts disabled alarm` → `fake.stored[1]!.enabled == false`.
  - `remove deletes` → state empty, `fake.calls.last == 'delete:1'`.
  - `build loads from platform` → fake pre-seeded with 2 alarms → state length 2.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(alarm): add alarm list state`

### Task 6: Alarm list, edit screen, preflight banner, routing

**Files:**
- Create: `lib/alarm/ui/alarm_list_screen.dart`, `lib/alarm/ui/alarm_edit_screen.dart`, `lib/alarm/ui/preflight_banner.dart`, `lib/app/routes.dart`
- Modify: `lib/app/app.dart` (use `onGenerateRoute: generateRoute`, `initialRoute` from `PlatformDispatcher.instance.defaultRouteName`)
- Test: `test/alarm/ui/alarm_list_screen_test.dart`, `test/alarm/ui/alarm_edit_screen_test.dart`, `test/alarm/ui/preflight_banner_test.dart`, `test/app/routes_test.dart`

**Interfaces:**
- Consumes: `alarmListProvider`, `permissionStatusProvider`, `alarmPlatformProvider`.
- Produces: `Route<dynamic>? generateRoute(RouteSettings s)` handling `/` → `AlarmListScreen`, `/edit` (arguments: `Alarm?`) → `AlarmEditScreen`, `/ring/<id>` → `RingScreen(alarmId: id)` (Task 7; until then route to a placeholder) — unknown → `/`.
  Widget keys used by tests and later phases: `Key('add-alarm')` FAB, `Key('alarm-tile-<id>')`, `Key('alarm-switch-<id>')`, `Key('save-alarm')`, `Key('day-chip-<1..7>')`, `Key('preflight-banner')`, `Key('fix-<permissionKindName>')`.
  - List tile: `timeLabel`, label, repeat summary (`Once`, `Every day`, `Weekdays`, `Weekends`, or `Mon, Wed, Fri`), switch; swipe to delete (`Dismissible`).
  - Edit screen: `TimePickerDialog` via a time button (default next full hour), 7 `FilterChip`s Mon–Sun, label `TextField`, Save → `add` or `save`, then pop.
  - Preflight banner: hidden when `allGranted`; else card titled `Alarms may not ring` listing each missing permission with a `Fix` button → `openSettings(kind)`; list screen re-reads `permissionStatusProvider` on `AppLifecycleState.resumed`.

- [ ] **Step 1: Write failing widget tests** (override providers with `FakeAlarmPlatform`):
  - `listShowsAlarmsWithRepeatSummary` → seeded `{1,2,3,4,5}` shows `Weekdays`; `{}` shows `Once`; `{1..7}` shows `Every day`.
  - `toggleSwitchDisablesAlarm` → tap `alarm-switch-1` → `fake.stored[1]!.enabled` is false.
  - `addFlowCreatesAlarm` → tap `add-alarm`, tap `day-chip-1`, tap `save-alarm` → `fake.stored` has one alarm with `repeatDays {1}`.
  - `preflightBanner_listsMissingPermissions` → fake missing `notifications` → finds `preflight-banner` and `fix-notifications`; tap → `fake.calls.last == 'openSettings:notifications'`. With all granted → `preflight-banner` not found.
  - `routes_test`: `generateRoute(RouteSettings(name: '/ring/7'))` builds a widget whose `alarmId == 7`; `/nope` → `AlarmListScreen`.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** all tests → PASS; update `app_smoke_test` expectation if needed.
- [ ] **Step 5: Commit** `feat(ui): alarm list, edit screen and preflight banner`

### Task 7: Ring screen (Phase 0: plain Stop / Snooze)

**Files:**
- Create: `lib/ringing/ring_screen.dart`
- Modify: `lib/app/routes.dart` (wire `/ring/<id>`)
- Test: `test/ringing/ring_screen_test.dart`

**Interfaces:**
- Consumes: `alarmPlatformProvider`, `alarmListProvider`.
- Produces: `class RingScreen extends ConsumerWidget { const RingScreen({required this.alarmId, this.onFinished}); final int alarmId; final VoidCallback? onFinished; }` — `onFinished` defaults to `SystemNavigator.pop` (closes `RingActivity`). Keys `Key('stop')`, `Key('snooze')`. Phase 1 replaces the button area with the stage engine; keep the button row in its own private widget.
  Shows current time (updates each second), alarm label, `Stop` and `Snooze 9 min`. `PopScope(canPop: false)`.

- [ ] **Step 1: Write failing tests**
  - `stopCallsPlatformAndFinishes` → tap `stop` → `fake.calls` contains `stopRinging`, `onFinished` called once.
  - `snoozeUses9Minutes` → tap `snooze` → `fake.calls` contains `snooze:7:9`, then `stopRinging`, `onFinished` called.
  - `ringScreen_backDoesNotPop` → push RingScreen on a Navigator over a base route, call `tester.binding.handlePopRoute()` → RingScreen still found.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement.** **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ringing): add plain ring screen`

### Task 8: Kotlin alarm core (pure, JVM-tested)

**Files:**
- Create: `android/app/src/main/kotlin/com/mrgardener/byebyesleep/alarm/AlarmSpec.kt`, `NextTrigger.kt`, `AlarmLifecycle.kt` (contains interfaces `AlarmRepository`, `AlarmClockScheduler`)
- Modify: `android/app/build.gradle.kts` (`testImplementation("junit:junit:4.13.2")`, `testImplementation("org.json:json:20240303")`), `.github/workflows/ci.yml` (step after `flutter build apk --debug`: `working-directory: android`, `run: ./gradlew testDebugUnitTest`)
- Test: `android/app/src/test/kotlin/com/mrgardener/byebyesleep/alarm/NextTriggerTest.kt`, `AlarmLifecycleTest.kt`, `AlarmSpecTest.kt`

**Interfaces:**
- Produces:
  ```kotlin
  data class AlarmSpec(val id: Int, val hour: Int, val minute: Int, val repeatDays: Set<Int>,
                       val label: String, val enabled: Boolean, val snoozeUntilMs: Long? = null) {
    fun toJson(): JSONObject; fun toChannelMap(): Map<String, Any?> // channel keys match Task 4 (snoozeUntilMs omitted)
    companion object { fun fromJson(o: JSONObject): AlarmSpec; fun fromChannelMap(m: Map<*, *>): AlarmSpec }
  }
  object NextTrigger { fun compute(spec: AlarmSpec, now: ZonedDateTime): ZonedDateTime }
  interface AlarmRepository { fun all(): List<AlarmSpec>; fun get(id: Int): AlarmSpec?; fun put(spec: AlarmSpec); fun remove(id: Int) }
  interface AlarmClockScheduler { fun schedule(id: Int, triggerAtMs: Long); fun cancel(id: Int) }
  class AlarmLifecycle(private val repo: AlarmRepository, private val scheduler: AlarmClockScheduler,
                       private val clock: () -> ZonedDateTime) {
    fun upsert(spec: AlarmSpec): Long?   // saves with snoozeUntilMs=null; cancel; schedule NextTrigger if enabled
    fun delete(id: Int)
    fun onFired(id: Int)                 // clears snooze; one-shot → enabled=false + cancel; repeating → schedule next regular
    fun snooze(id: Int, minutes: Int): Long // snoozeUntilMs = now+minutes; schedule it
    fun rescheduleAll()                  // future snooze wins; else enabled → NextTrigger; else cancel
  }
  ```
  `NextTrigger.compute`: earliest instant strictly after `now` whose local date's ISO weekday is in `repeatDays` (any day if empty) at `hour:minute`, built with `ZonedDateTime.of(date, LocalTime.of(hour, minute), now.zone)` (java.time shifts gap times forward, picks earlier offset in overlaps). Scan at most 8 days.

- [ ] **Step 1: Write failing tests** (`zone = ZoneId.of("America/New_York")`):

```kotlin
@Test fun oneShot_laterToday() = assertEquals(at(2026,10,12,7,0), NextTrigger.compute(spec(7,0), at(2026,10,12,6,0)))
@Test fun oneShot_sameMinute_goesTomorrow() = assertEquals(at(2026,10,13,7,0), NextTrigger.compute(spec(7,0), at(2026,10,12,7,0)))
@Test fun repeat_skipsToNextAllowedDay() = // 2026-10-12 is Monday; days {3}=Wed
  assertEquals(at(2026,10,14,7,0), NextTrigger.compute(spec(7,0, setOf(3)), at(2026,10,12,8,0)))
@Test fun nextTrigger_springForwardGap() = // 2026-03-08 02:30 does not exist
  assertEquals(ZonedDateTime.of(2026,3,8,3,30,0,0,zone), NextTrigger.compute(spec(2,30), at(2026,3,8,0,0)))
@Test fun nextTrigger_fallBackOverlap() { // 2026-11-01 01:30 occurs twice → first (EDT, -04:00)
  val r = NextTrigger.compute(spec(1,30), at(2026,11,1,0,0)); assertEquals(ZoneOffset.ofHours(-4), r.offset) }
@Test fun onFired_oneShot_disables() { lifecycle.upsert(spec(7,0)); lifecycle.onFired(1)
  assertFalse(repo.get(1)!!.enabled); assertEquals("cancel:1", sched.calls.last()) }
@Test fun onFired_afterSnooze_schedulesNextRegular() { // repeating daily
  lifecycle.upsert(spec(7,0, (1..7).toSet())); now = at(2026,10,12,7,0); lifecycle.snooze(1, 9)
  now = at(2026,10,12,7,9); lifecycle.onFired(1)
  assertNull(repo.get(1)!!.snoozeUntilMs); assertEquals(sched.scheduled[1], at(2026,10,13,7,0).toInstant().toEpochMilli()) }
@Test fun rescheduleAll_restoresFutureSnooze() { /* one-shot fired (disabled) then snoozed to 07:09; now 07:05 → scheduled[1] == 07:09 */ }
@Test fun rescheduleAll_ignoresPastSnoozeAndDisabled() { /* disabled one-shot with snooze 07:09, now 07:30 → cancel:1 */ }
@Test fun upsert_disabled_cancelsAndReturnsNull()
@Test fun json_roundTrip() / channelMap_roundTrip() // AlarmSpecTest
```
  (`at(...)` builds `ZonedDateTime` in `zone`; `spec(h,m,days=emptySet())` uses id 1; `repo`/`sched` are in-memory fakes in the test file recording `schedule:<id>` / `cancel:<id>` and a `scheduled: MutableMap<Int, Long>`; `now` is a `var` read by `clock`.)

- [ ] **Step 2: Run** `cd android && ./gradlew testDebugUnitTest` → FAIL (needs `flutter build apk --debug` once first so Gradle has the Flutter plugin; if no Android SDK locally, push and use CI as the runner).
- [ ] **Step 3: Implement** the three files.
- [ ] **Step 4: Run** → PASS (12 tests).
- [ ] **Step 5: Commit** `feat(android): pure alarm scheduling core with DST-safe next trigger`

### Task 9: Android alarm engine wiring

**Files:**
- Create (all in `android/app/src/main/kotlin/com/mrgardener/byebyesleep/alarm/`): `PrefsAlarmRepository.kt`, `AndroidAlarmClockScheduler.kt`, `AlarmReceiver.kt`, `AlarmService.kt`, `BootReceiver.kt`, `AlarmChannel.kt`, `Permissions.kt`; `android/app/src/main/kotlin/com/mrgardener/byebyesleep/RingActivity.kt`
- Modify: `MainActivity.kt`, `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: Task 8 core; channel contract from Task 4; route `/ring/<id>` from Task 6.
- Produces:
  - `PrefsAlarmRepository(context)`: SharedPreferences file `alarms`, key `alarms_json` (JSON array of `AlarmSpec.toJson()`).
  - `AndroidAlarmClockScheduler(context)`: `setAlarmClock(AlarmClockInfo(triggerAtMs, showIntent → MainActivity), operation)`; `operation` = broadcast `PendingIntent` to `AlarmReceiver`, `requestCode = id`, extra `alarm_id`, `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT`; `cancel` cancels the same PendingIntent.
  - `AlarmLifecycle.forContext(context)` factory (in `AlarmChannel.kt` or a small `AlarmGraph.kt`) using system default zone.
  - `AlarmReceiver`: `lifecycle.onFired(id)`; `startForegroundService(AlarmService.ring(context, id))`.
  - `AlarmService`: foreground with `ServiceInfo.FOREGROUND_SERVICE_TYPE_SYSTEM_EXEMPTED`; notification channel `alarm_ringing` (IMPORTANCE_HIGH, no sound — audio is played by the service), `CATEGORY_ALARM`, ongoing, `setFullScreenIntent(→ RingActivity with alarm_id, true)`; plays `RingtoneManager.TYPE_ALARM` default (fallback `TYPE_RINGTONE`) via `MediaPlayer` looping, `USAGE_ALARM`; stores previous `STREAM_ALARM` volume, sets max, restores on stop; vibrates waveform `[0, 800, 600]` repeating; holds partial wake lock while ringing (max 30 min). Intents: `ACTION_RING` (if already ringing, switch displayed id), `ACTION_STOP`, `ACTION_RING_ACTIVITY_GONE` (re-post the full-screen notification while still ringing). Static `ringingAlarmId: Int?`.
  - `RingActivity : FlutterActivity`: `getInitialRoute() = "/ring/$alarmId"`; `setShowWhenLocked(true)`, `setTurnScreenOn(true)`, keyguard dismiss request not required; consumes `KEYCODE_VOLUME_UP/DOWN/MUTE` in `onKeyDown`; `onDestroy` → if `AlarmService.ringingAlarmId != null` send `ACTION_RING_ACTIVITY_GONE`; `launchMode="singleTask"`, `excludeFromRecents`, `taskAffinity` separate from main.
  - `BootReceiver`: `BOOT_COMPLETED`, `TIME_SET`, `TIMEZONE_CHANGED`, `MY_PACKAGE_REPLACED` → `rescheduleAll()`.
  - `AlarmChannel.register(engine, context)`: implements the Task 4 methods; `stopRinging` → `AlarmService` `ACTION_STOP`; `snooze` → `lifecycle.snooze` then return trigger. Called from both `MainActivity.configureFlutterEngine` and `RingActivity.configureFlutterEngine`.
  - `Permissions`: `exactAlarm` = `AlarmManager.canScheduleExactAlarms()`; `fullScreenIntent` = `NotificationManager.canUseFullScreenIntent()` on API 34+ else true; `notifications` = `areNotificationsEnabled()`; `ignoreBatteryOptimizations` = `PowerManager.isIgnoringBatteryOptimizations`. `openSettings` maps to `ACTION_REQUEST_SCHEDULE_EXACT_ALARM`, `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT`, `ACTION_APP_NOTIFICATION_SETTINGS`, `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (with `package:` URI). On first launch `MainActivity` requests `POST_NOTIFICATIONS` at runtime (API 33+).
  - Manifest: permissions from Global Constraints; receivers `exported="false"` except `BootReceiver` (`exported="true"` for system broadcasts); service `foregroundServiceType="systemExempted"`.

- [ ] **Step 1: Implement** the files above.
- [ ] **Step 2: Verify build** — `flutter build apk --debug` and `cd android && ./gradlew testDebugUnitTest lintDebug` → success, no new lint errors of severity Error (push to CI if no local SDK).
- [ ] **Step 3: Commit** `feat(android): alarm engine (scheduler, receiver, ringing service, ring activity, boot)`
- [ ] (Runtime behaviour is verified by Task 10's emulator test and Task 11's Pixel checklist.)

### Task 10: Emulator smoke test

**Files:**
- Create: `.github/workflows/android-emulator.yml`, `tool/emulator_smoke.sh`
- Modify: `MainActivity.kt` (debug-only hook)

**Interfaces:**
- Consumes: Task 9 engine.
- Produces: debug-only intent extra on `MainActivity`: `debug_ring_in_seconds` (Int). When `BuildConfig.DEBUG` and present, upserts alarm id `9999` (one-shot, label `smoke`) and schedules it via `AndroidAlarmClockScheduler.schedule(9999, now + seconds*1000)` (bypassing minute rounding).

- [ ] **Step 1: Write `tool/emulator_smoke.sh`** (bash, `set -euo pipefail`): install `build/app/outputs/flutter-apk/app-debug.apk`; `pm grant com.mrgardener.byebyesleep android.permission.POST_NOTIFICATIONS`; `appops set com.mrgardener.byebyesleep USE_FULL_SCREEN_INTENT allow`; `am start -n com.mrgardener.byebyesleep/.MainActivity --ei debug_ring_in_seconds 30`; wait 5 s; `input keyevent KEYCODE_HOME` then `input keyevent KEYCODE_SLEEP` (screen off, app backgrounded); poll up to 90 s for `dumpsys activity activities | grep -q 'RingActivity'`; also assert `dumpsys media.audio_flinger` or `dumpsys audio | grep -q 'USAGE_ALARM'` while ringing; exit 1 on timeout, print `SMOKE OK` on success.
- [ ] **Step 2: Write workflow** — triggers: `push` to `main`, `workflow_dispatch`; `ubuntu-latest`; enable KVM (udev rule step from the android-emulator-runner README); build debug APK; `reactivecircus/android-emulator-runner@v2` with `api-level: 34`, `target: google_apis`, `arch: x86_64`, `script: bash tool/emulator_smoke.sh`.
- [ ] **Step 3: Verify** — push, run via `workflow_dispatch` on the branch, confirm `SMOKE OK` in logs. Iterate until green.
- [ ] **Step 4: Commit** `ci: emulator smoke test that the alarm rings while the screen is off`

### Task 11: Release workflow, signing, Pixel checklist

**Files:**
- Create: `.github/workflows/release.yml`, `docs/testing/pixel-checklist.md`
- Modify: `android/app/build.gradle.kts` (release signing), `README.md` (install section), `.gitignore` (`android/key.properties`, `*.jks`)

**Interfaces:**
- Produces: release signing reads `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) if present, else falls back to debug signing (so CI never fails for missing secrets; the release notes then say "debug-signed").

- [ ] **Step 1: `release.yml`** — trigger `push` tags `v*`; ubuntu; flutter-action pinned; if secret `ANDROID_KEYSTORE_BASE64` non-empty, decode to `android/app/release.jks` and write `android/key.properties` from secrets `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`; `flutter build apk --release --build-name ${GITHUB_REF_NAME#v} --build-number ${{ github.run_number }}`; rename to `ByeByeSleep-${GITHUB_REF_NAME}.apk`; `softprops/action-gh-release@v2` with `generate_release_notes: true`.
- [ ] **Step 2: Pixel checklist** `docs/testing/pixel-checklist.md` — numbered checks with expected result: install from release; grant all preflight items (banner disappears); alarm 2 min ahead rings on lock screen with screen off; volume keys don't silence; back gesture doesn't close ring screen; swipe app away from recents then alarm still rings; `adb shell dumpsys deviceidle force-idle` then alarm rings; reboot with alarm set → rings; snooze → rings 9 min later; reboot during snooze → still rings; DND on → rings; repeating alarm → next day's alarm shown in status bar after Stop; change time zone → alarm time follows local clock.
- [ ] **Step 3: README** — "Install on Android: download the APK from the latest GitHub Release (or the `byebyesleep-debug-apk` artifact of a PR's CI run), allow 'Install unknown apps' for your browser/files app, open the APK." Plus one line how the owner creates a keystore (`keytool -genkeypair -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias byebyesleep`) and adds the 4 secrets.
- [ ] **Step 4: Verify** YAML parses (same python check as Task 2); `flutter build apk --release` works without `key.properties` (debug-signed fallback) — locally or in CI.
- [ ] **Step 5: Commit and push** `ci: release workflow and Pixel test checklist`; confirm CI green on the branch.

---

## Done when

- CI (`dart`, `ios-compile`) green on the branch; emulator smoke test prints `SMOKE OK`.
- A debug APK artifact is downloadable from the latest CI run.
- Owner has run `docs/testing/pixel-checklist.md` on the Pixel 10 Pro (owner action; reported back before Phase 1 planning).
