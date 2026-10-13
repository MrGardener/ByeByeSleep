# Watch Heart Rate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** A "Get your heart going" challenge (and Sensor Quest world "Pulse Run") that reads live heart rate from a Pixel Watch 3 while you walk up and down the stairs.

**Architecture:**
- A small Wear OS app (`android/wear`, plain Kotlin and Views, no Compose) reads `Sensor.TYPE_HEART_RATE` in the foreground and sends each bpm to the phone over the Wearable Data Layer (`MessageClient`, path `/hr/bpm`).
- The phone (`WatchChannel.kt`) opens the watch app with `RemoteActivityHelper` when the challenge starts, streams the bpm to Dart on `byebyesleep/heart_rate`, and sends `/hr/stop` when the challenge ends.
- The watch app advertises the capability `byebyesleep_heart_rate`, so the phone knows a watch is ready.
- The Data Layer only connects apps with the same package name and signing key. Both use `com.mrgardener.byebyesleep` and the shared test key.

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md`, §4.5 Tier A (Pulse Run, smartwatch). The owner chose "Watch app, live" on 2026-10-13.

## Global Constraints

- Watch: `minSdk 30` (Wear OS 3+); Pixel Watch 3 runs Wear OS 5+.
- Permissions: `BODY_SENSORS` up to API 35, `android.permission.health.READ_HEART_RATE` from 36.
- Pass rule:
  - The baseline is the median of the first 5 readings.
  - The goal is `max(baseline + rise, 90)` with `rise = 10 + 5 × difficulty`.
  - The challenge passes after 15 s in total at or above the goal.
- No watch, or no answer within 5 s → `onUnavailable`, which swaps in the fallback challenge.
- No new Flutter plugins. Phone dependencies are `play-services-wearable` and `wear-remote-interactions`; the watch only needs `play-services-wearable`.
- CI builds the watch APK. The latest-apk workflow also publishes `ByeByeSleep-watch.apk`.

## Rulings

- `SensorManager` heart rate instead of Health Services: one dependency fewer, and Google Maven cannot be reached from this environment to check versions. Cost if wrong: readings may be less smooth.
- Installing on the watch needs a computer once (ADB over Wi-Fi). `docs/watch-install.md` gives the steps.

## Tasks

1. **Dart detector:** `lib/challenges/heart_rate/detector.dart` with `HeartRateGoal(difficulty).add(int bpm, Duration t)` and a progress value. Tests: baseline, goal floor of 90, 15 s accumulated (not necessarily continuous), and zero or invalid bpm ignored.
2. **Dart source and challenge:**
   - `core/heart_rate.dart`: `HeartRateSource {available(); Stream<int> bpm}`, plus a channel implementation and a capability probe.
   - `SensorKind.heartRate`.
   - Widget with live bpm, goal and progress; registry entry `ChallengeId.heartRate`; estimate entry.
   - Tests: widget passes with a fake source; no watch means unavailable; `resolveStage` falls back when there is no watch.
3. **Phone native:** `WatchChannel.kt` (available, start, stop, bpm stream) registered in both activities, plus dependencies.
4. **Wear module:** `android/wear` with manifest, `HeartRateActivity`, capability resource and signing; `settings.gradle.kts` includes `:wear`; CI and the release/latest workflows build and publish the watch APK.
5. **Sensor Quest "Pulse Run"** world, docs (`docs/watch-install.md`, README) and checklist rows.
