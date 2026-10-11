# ByeByeSleep — Design Spec

- **Date:** 2026-10-11
- **Status:** Draft, awaiting owner review
- **Repo:** `mrgardener/byebyesleep` (public)
- **First test device:** Google Pixel 10 Pro (Android 16)

## 1. Goal

ByeByeSleep is an Android + iPhone alarm clock that cannot be silenced by a
half-asleep person. Ringing alarms walk the user through up to **four stages of
challenges** that use the phone's sensors (motion, camera, light, NFC, steps,
microphone, …). **Snooze and Stop only appear after the last stage.**

The app also contains **Sensor Quest**, a game whose levels each exercise a
different phone sensor; it doubles as a practice mode for the alarm challenges.

### Success criteria

1. The alarm fires on time every day on the Pixel 10 Pro, including after reboot,
   in Doze, in Do-Not-Disturb, and after the app was swiped away.
2. The user physically leaves the bed (steps + photo/NFC at a remote spot) before
   the alarm can be stopped.
3. The user is never locked out: a safety exit always exists (§6.4).
4. Every pull request is built and tested on GitHub Actions; installable Android
   APKs and an unsigned iOS build are produced by CI, with no local machine needed.

### Constraints given by the owner

- Lives on GitHub; PRs, checks and app builds run there.
- Repo is public (free GitHub-hosted macOS runners).
- **No Apple Developer account.** iOS is built unsigned in CI; installing on an
  iPhone requires sideloading (§9.3). No TestFlight / App Store for now.

## 2. Platform reality

### 2.1 Alarm control

| | Android | iOS |
|---|---|---|
| Firing | `AlarmManager.setAlarmClock()` + full-screen intent + foreground service. Permissions `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT` (both allowed for alarm-clock apps). | **AlarmKit** (iOS 26+): breaks through silent mode/Focus; system renders the alert. |
| Hide stop/snooze until done | Yes — our own full-screen activity, volume keys intercepted, alarm stream volume forced. | No — the system alert always offers stop. Mitigation: **backup alarm chain** (§5.3). |
| Volume | App forces `STREAM_ALARM` volume. | System alarm volume; app cannot change it. |

Consequence: **Android-first.** iOS ships the same challenges with the chain
mitigation in Phase 2.

### 2.2 Sensor feasibility (third-party app access)

| Sensor / capability | Pixel 10 Pro | iPhone | Use |
|---|---|---|---|
| Accelerometer, gyroscope, rotation vector, gravity, linear accel. | Yes | Yes (CoreMotion) | Mazes, orientation, gestures, hold-still |
| Step detector / counter | Yes | Yes (CMPedometer) | Walk challenge |
| Activity recognition (walking/still) | Yes | Yes (CMMotionActivityManager) | Anti-cheat for steps |
| Barometer | Yes | Yes (CMAltimeter) | Stair-climb challenge |
| Magnetometer | Yes | Yes | Compass challenge |
| Proximity | Yes | Yes (binary) | Cover/shadow gestures |
| Ambient light | Yes (`TYPE_LIGHT`) | **No public API** → camera frame luminance | Lights-on gate |
| Cameras (rear + front) | Yes | Yes | Photo match, colour/object hunt, face, heart rate |
| Microphones | Yes | Yes | Speech, pitch, loudness, sound classification |
| NFC (NDEF read) | Yes | Yes (Core NFC system sheet) | NFC treasure hunt |
| Barcode / QR | Yes (ML Kit) | Yes (ML Kit) | Barcode mission |
| Bluetooth LE RSSI | Yes | Yes | Beacon hot/cold (Tier B) |
| Wi-Fi RSSI | Yes | No | Android-only (Tier B) |
| GNSS | Yes | Yes | "Step outside" only; raw GNSS not used |
| UWB | Yes (needs 2nd UWB device) | Apple devices only | Optional, game only |
| Battery level / charging | Yes | Yes | Charger challenge, battery-guess game level |
| Haptics | Yes | Yes (Core Haptics) | Haptic code challenges |
| Touch | Yes (no pressure on Pixel) | Yes | UI games |
| Volume keys | Interceptable in foreground | No | Block silencing (Android) |
| Power key | No | No | — |
| Fingerprint / Face ID | Pass/fail only | Pass/fail only | Protect "disable alarm" settings |
| IR temperature sensor | Not on Pixel 10 Pro; never had an API | No | **Dropped** |
| LDAF, spectral/flicker, Hall sensor | No public API | No | **Dropped** |
| SoC thermal / Titan M2 / TPU | Coarse thermal status; TPU used implicitly by ML | Coarse | Not used as challenges |

## 3. Architecture

### 3.1 Stack

- **Flutter (stable channel, pinned in CI)**, Dart for all UI, challenges, game.
- **Native alarm engines** via a platform channel `byebyesleep/alarm`:
  Kotlin (Android) and Swift (iOS AlarmKit).
- **Flame** for game rendering (mazes and Sensor Quest).
- **Riverpod** for state, **drift** (SQLite) for persistence.
- Plugins: `sensors_plus`, `pedometer`, `camera`, `google_mlkit_face_detection`,
  `google_mlkit_barcode_scanning`, `google_mlkit_object_detection`,
  `nfc_manager`, `battery_plus`, `speech_to_text`, `flutter_blue_plus`.
  Sensors without a reliable plugin (Android light sensor, barometer,
  activity recognition) go through a small native `byebyesleep/sensors` channel.

### 3.2 Module layout

```
lib/
  app/                 # routing, theme, DI
  alarm/               # Alarm model, repository, scheduler facade (platform channel)
  ringing/             # Stage engine + ringing screen + safety exit
  challenges/
    core/              # Challenge interface, SensorSource abstractions, registry
    <challenge_id>/    # one folder per challenge: detector.dart (pure), widget.dart, setup.dart
  setup/               # mission setup wizard (reference photo, NFC tag, step calibration…)
  game/                # Sensor Quest worlds (reuse challenges/*)
  sensors/             # Stream adapters over plugins/native channels + trace recorder
android/app/src/main/kotlin/.../alarm/   # AlarmScheduler, AlarmReceiver, AlarmService, BootReceiver, RingActivity
ios/Runner/Alarm/                        # AlarmKitScheduler, BackupChain
test/                  # unit + golden; test/fixtures/traces/*.json recorded sensor data
```

### 3.3 Challenge contract

Every challenge is split into a **pure detector** and a **widget**:

```dart
abstract class ChallengeDetector {
  /// Feed one normalized sensor event; returns current progress.
  ChallengeProgress onEvent(SensorEvent e);
  ChallengeProgress get progress; // 0.0–1.0, plus passed / failed flags
}
```

- Detectors have no Flutter or plugin imports → unit-tested in CI with
  recorded traces (`SensorEvent` streams serialised to JSON).
- A hidden **Trace Recorder** developer screen records real sensor streams on
  the Pixel to create new fixtures.
- Each challenge declares: `id`, required sensors, platforms supported,
  difficulty levels (1–5), and an optional setup step.
- The stage engine only offers challenges whose required sensors are present
  on the current device.

## 4. Product design

### 4.1 Alarm model

`Alarm { id, time, repeatDays, label, sound, stages: List<StageConfig>,
snoozeMinutes, maxSnoozes, followUpCheck: bool, enabled }`
`StageConfig { challengeId, difficulty, params (e.g. referencePhotoId, nfcTagId, steps) }`

### 4.2 The four-stage flow (default template)

1. **Lights** — screen black, sound escalating. Room light must exceed the lux
   level measured at setup (Android light sensor; iOS camera luminance). Then
   the stage game appears.
2. **Move** — walk ≥ 80% of the calibrated bed-to-spot step count (step
   detector + activity recognition must report walking), then complete the
   location proof: **photo match**, **NFC tag**, or **barcode**.
3. **Brain** — tilt maze or cognitive game at the configured difficulty.
4. **Proof** — eyes-open selfie (Phase 3) or a quick cognitive check (MVP).
   Then **Snooze** and **Stop** are shown.

Between stages the alarm drops to low volume for a **breather** (default 20 s,
countdown visible) and then escalates again. Users can reorder, remove or swap
stages; minimum one stage.

**Follow-up check** (optional, Phase 3): 5–10 min after Stop, a notification
must be answered within 60 s or the alarm restarts at stage 3.

### 4.3 Photo match (owner's idea, refined)

- Setup: take **two** reference photos of the spot with lights on.
- Score = weighted combination of (a) HSV colour-histogram correlation after
  brightness normalisation and (b) structural similarity of downscaled
  grayscale edge maps. Pure Dart, in the detector.
- Default pass threshold **0.90**, adjustable 0.75–0.95. Setup computes the
  self-similarity of the two reference shots and warns if it is not
  comfortably above the threshold.
- Histogram-only matching is not used alone: it fails under changed lighting
  and passes any similarly coloured scene.

### 4.4 Maze difficulty ladder

| Level | Control |
|---|---|
| 1 | Drag with finger |
| 2 | Tilt (accelerometer) |
| 3 | Tilt, inverted axes |
| 4 | Tilt + rotate phone (gyro) to rotate the maze |
| 5 | Tilt + moving walls; ball freezes unless phone yaw stays within ±15° of a drifting target heading (gyro + magnetometer) |

Maze is only visible while the lights-on condition holds (stage 1 coupling).

### 4.5 Challenge catalogue

**Tier S — MVP (Phase 1)**

| Id | Challenge | Sensors |
|---|---|---|
| `lights_on` | Dark screen until room is lit | Light / camera |
| `walk_steps` | Walk N steps | Step detector + activity |
| `photo_match` | Match reference photo | Camera |
| `nfc_tag` | Tap registered NFC sticker | NFC |
| `barcode` | Scan registered barcode/QR | Camera + ML Kit |
| `charger` | Plug phone into charger (away from bed) | Battery |
| `tilt_maze` | Maze levels 1–5 | Accel / gyro / touch |
| `broken_calculator` | Math with shuffling keypad | Touch |
| `stroop_tap` | Tap the ink colour, not the word | Touch |
| `orientation_hopscotch` | Flip phone through shown orientations | Accel / gravity |

**Tier A — Phase 3:** eyes-open selfie, camera colour hunter, light thief, haptic
pulse code, silent vibration rhythm, bilateral tapping, chrono-estimator,
peripheral vision zap, mirror-image tracing, inverted-control maze variant,
hold-still (combo only), tongue twister (on-device speech), vowel pitch match,
singing scale, air-canvas gesture, barometer stair climb, camera heart-rate,
object hunt (ML Kit), follow-up check.

**Tier B — Phase 4/5:** weather soundscapes (Open-Meteo), Cliffhanger story
(Gemini Nano / Apple Foundation Models), laughter detection, rhyme chain,
conversation partner, story continuation, haiku, Bluetooth anchor, Wi-Fi
proximity (Android), app-lock gatekeeper, shadow catcher, optical focus run,
micro-typography, Synchronized Chain (needs backend), smart-home lights,
smartwatch companion, sleep-stage smart wake.

**Rejected:** thermal handshake, grip pressure, thermal shock wave, flashlight
beam track, echolocation (both), clap echo, audio-cable unplug (no jack),
decibel silence, whisper mode, storage cleaner (data loss), false memory check,
spatial audio navigation, synesthesia, audio illusions, Smart TV cast, flashlight
code receiver. "Pattern disruption" is kept as an alarm **sound style**, not a
challenge.

## 5. Alarm engines

### 5.1 Android

- `AlarmScheduler` uses `setAlarmClock()` (shows in status bar, exempt from Doze).
- `AlarmReceiver` → starts `AlarmService` (foreground, type `systemExempted`,
  allowed for `USE_EXACT_ALARM` holders) which plays audio on `STREAM_ALARM`,
  forces volume, vibrates, and posts a full-screen-intent notification.
- `RingActivity` (`showWhenLocked`, `turnScreenOn`) hosts Flutter route
  `/ring/<alarmId>`; intercepts volume keys; back is disabled.
- If the activity is destroyed while ringing, the service relaunches it.
- `BootReceiver` and `TIME_SET`/`TIMEZONE_CHANGED` re-schedule all alarms.
- Snooze reschedules via `setAlarmClock()`.

### 5.2 iOS (Phase 2)

- `AlarmKitScheduler` schedules the main alarm with a secondary button
  "Start challenges" whose intent opens the app at `/ring/<alarmId>`.
- Minimum iOS 26.

### 5.3 iOS backup chain

With each alarm, schedule up to 10 backup alarms at +2 min intervals. Only
completing the stages (or the safety exit) cancels the remaining chain. Stopping
the system alert alone therefore only buys ~2 minutes.

## 6. Reliability & safety

1. **Pre-flight check** (evening notification + on alarm save): permissions
   granted (exact alarm, full-screen intent, notifications, camera, activity
   recognition), battery optimisation exempt, mission assets present.
2. **Sensor missing at ring time** (e.g. camera fails): the stage auto-substitutes
   a same-tier challenge not needing that sensor; logged.
3. **Challenge timeout:** each stage has a hint after 2 min and offers a
   fallback challenge after 5 min.
4. **Safety exit:** after 15 min of ringing, a "Type this paragraph" exit
   becomes available; it dismisses the alarm (no snooze).
5. Settings that weaken alarms (delete/disable during the 30 min before an
   alarm) require biometric confirmation.
6. All processing is on-device; photos never leave the phone. No analytics in MVP.

## 7. Sensor Quest (game)

Each world reuses challenge detectors at game difficulty; completing worlds
unlocks the next. Also reachable as "Practice" for any alarm challenge.

| World | Mechanic | Sensors |
|---|---|---|
| Labyrinth | Tilt maze | Accelerometer / gyroscope |
| Compass Temple | Reach headings in sequence | Magnetometer |
| Solar Garden | Grow plants with real light | Light sensor / camera |
| Sky Tower | Climb real stairs | Barometer |
| Ghost Hide | Cover phone to hide from ghost | Proximity |
| Choir Cave | Sing target pitch | Microphone |
| Color Safari | Find real colours / objects | Camera + ML Kit |
| Rune Hunt | Collect user-placed NFC stickers | NFC |
| Beacon Seek | Hot/cold to a BLE device (UWB precision on Pixel when available) | Bluetooth / UWB |
| **Battery Oracle** | **Guess the battery percentage** | Battery level |
| Pulse Run | Raise heart rate | Camera PPG |
| Bomb Defuse | Feel a haptic code, tap it back | Haptics |

**Battery Oracle rule:** the player enters a whole-number percentage 0–100.
The real level is read at submit time. The guess succeeds when
`|guess − actual| ≤ 25`, i.e. accepted range `[max(0, actual−25), min(100, actual+25)]`
(e.g. 9% → 0–34 accepted). The status bar is hidden during the level
(immersive mode on Android, `prefersStatusBarHidden` on iOS) so the level
cannot be read from the screen; on iOS Control Center can still reveal it,
accepted as a game (not security) limitation.

## 8. Testing

- **Unit:** every detector against recorded trace fixtures (pass, fail, cheat
  attempts like shaking-for-steps), stage engine state machine, scheduling
  time maths (DST, time-zone change, repeat days), Battery Oracle tolerance edges.
- **Widget / golden:** ringing screen states, maze rendering, setup wizard.
- **Native:** Kotlin unit tests for next-trigger computation; Android
  emulator smoke test in CI (schedule alarm 1 min ahead, assert `RingActivity`
  launches) on pushes to `main`.
- **Manual on Pixel 10 Pro:** release checklist in `docs/testing/pixel-checklist.md`
  (reboot, Doze via `adb shell dumpsys deviceidle force-idle`, DND, swipe-away).

## 9. GitHub & CI/CD

### 9.1 Workflows

- `ci.yml` — on every PR and push:
  - `ubuntu-latest`: `dart format --set-exit-if-changed`, `flutter analyze`,
    `flutter test --coverage`, `flutter build apk --debug` → uploaded artifact.
  - `macos-latest`: `flutter build ios --simulator --debug` (compile check, unsigned).
- `android-emulator.yml` — on push to `main`: emulator smoke test (§8).
- `release.yml` — on tag `v*`:
  - Signed release APK (keystore from secrets `ANDROID_KEYSTORE_BASE64`,
    `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`);
    published to a GitHub Release for direct install on the Pixel.
  - Unsigned iOS `.ipa` (`flutter build ios --release --no-codesign`, packed
    into `Payload/`) attached to the same release, for sideloading.

### 9.2 Repo hygiene

Branch protection on `main` (CI required), PR template, Dependabot for pub,
Gradle and GitHub Actions, `CODEOWNERS`, issue templates for challenge ideas.

### 9.3 iPhone without a developer account

The unsigned `.ipa` can be sideloaded with a free Apple ID through tools such
as Sideloadly or AltStore. Free provisioning expires after 7 days and does not
grant every capability (NFC tag reading in particular must be verified). iOS is
therefore "best effort" until an Apple Developer account exists.

## 10. Roadmap

| Phase | Scope | Exit criterion |
|---|---|---|
| 0 | Flutter scaffold, CI workflows, Android alarm engine, plain ring screen with Stop | Alarm survives reboot/Doze/swipe-away on Pixel |
| 1 (MVP) | Stage engine, Tier S challenges, setup wizard, safety exit, pre-flight check | Owner uses it daily for a week |
| 2 | iOS AlarmKit + backup chain, unsigned IPA in releases | Builds in CI; alarm rings on a sideloaded iPhone |
| 3 | Tier A challenges, follow-up check, Sensor Quest worlds + practice mode | All worlds playable on Pixel |
| 4 | Weather soundscapes, Cliffhanger, speech challenges | — |
| 5 | Synchronized Chain backend, smart home, watch | — |

Each phase gets its own implementation plan in `docs/superpowers/plans/`.

## 11. Risks

- **Battery optimisation / OEM killers:** mitigated by `setAlarmClock` + FGS;
  Pixel is well-behaved.
- **Photo match false failures** at night: two-shot calibration, adjustable
  threshold, fallback after 5 min.
- **Step count latency** (counter batches): use step *detector* events.
- **Play Store policy** for full-screen intent / exact alarms: alarm-clock
  category qualifies; distribution is GitHub Releases for now anyway.
- **iOS cannot fully lock the alarm:** accepted; backup chain mitigates.
