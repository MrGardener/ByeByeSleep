# Awake Check, Stairs Challenge and Clean-ups — Plan

**Goal:** Spec §4.2 "follow-up check": after Stop, the alarm can ring once more a few
minutes later with one quick challenge, so dozing off again does not work. Also a
"Climb the stairs" alarm challenge (barometer) and the clean-ups the reviewers
deferred.

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md` §4.2, §4.5 (barometer stair climb).

## Decisions (owner delegated: "keep going")
- Setting per alarm, "Check I'm awake": Off (default), 5, 10, 15, 20 min. Stored in extras.
- The check ring is scheduled natively like a snooze (`snoozeUntilMs`) and marked with
  native-only `followUpAtMs`; `onFired` reports it, and the ring's `RingProgress`
  carries `followUp = true`, so a reboot or redelivered ring keeps knowing it.
- The check ring shows "Still awake?" and one quick challenge (Colour words, difficulty
  1). Stopping it does **not** schedule another check (no loop) and does not ask
  about the series again; the reminder shows again.
- Stairs challenge: the Sky Tower rule (0.30 hPa below the start, held 2 s ≈ one floor);
  needs a barometer, else the usual fallback.

## Tasks
1. Native: `AlarmLifecycle.followUp(id, minutes)`, `onFired` returns whether the ring is a
   check, `RingProgress.followUp`, `AlarmReceiver`/`AlarmService` pass it; channel
   method `followUp`. JVM tests.
2. Dart: `Alarm.followUpMinutes`, `RingProgress.followUp`, platform `followUp`; ring
   screen check mode; after Stop schedules the check; editor setting. Tests.
3. `ChallengeId.stairs` from `SkyTower`. Tests.
4. Clean-ups: reminder photos deleted when no alarm uses them; Solar Garden and Ghost
   Hide pause while the app is in the background; Labyrinth falls back when the
   accelerometer is silent. Tests.
