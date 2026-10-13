# Alarm Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the app into a clear set of alarm tools that work together: a time-to-stop estimate, alarm series, picture reminders, and a layout where each tool is easy to find.

**Architecture:**
- Series children are real native alarms. Dart generates them from the main alarm and marks each with its parent's id, so native scheduling stays one alarm = one trigger.
- Dart-only options (reminder, series settings, parent link) travel in a new pass-through `extrasJson` field on `AlarmSpec`, the same way `stagesJson` already does.
- "Skip the rest of the series today" is a native `skipNext(id)` that moves one alarm past its next ring.

**Tech Stack:** Flutter / Riverpod 3; Kotlin alarm engine (`AlarmLifecycle`, `NextTrigger`).

**Spec:** `docs/superpowers/specs/2026-10-11-byebyesleep-design.md`. Owner requests of 2026-10-13 (quoted in the PR); the owner's answers are below.

## Owner decisions (2026-10-13)

- **Series stop:** after a series alarm is stopped, the stop screen asks whether to skip the rest of the series today. Skipped alarms come back on their next due day.
- **Series challenges:** chosen per series, either "same as main alarm" or "one quick challenge" (Broken calculator, difficulty 2).
- **Reminder:**
  - The photo and caption show on the ring screen and full screen after Stop.
  - Reminder-only alarms (no challenges) are allowed.
- **Watch:** live heart rate from a Pixel Watch 3 companion app. This is a separate plan, after this one.

## Global Constraints

- **Series sizes:**
  - Count 2–10 alarms in total, including the main one.
  - Interval 1–30 minutes.
  - Direction `after` (the main alarm is the first) or `before` (the main alarm is the last, the "target").
- **Children:**
  - Children inherit the main alarm's repeat days, label, pause and reminder.
  - Challenges follow the series' follow-up choice.
  - Children cannot be edited on their own. Editing the main alarm regenerates them.
  - Deleting or disabling the main alarm does the same to its children.
- **Split:**
  - A warning dialog comes first.
  - Every child becomes a normal, independent alarm.
  - The main alarm loses its series settings.
- **Midnight wrap:** a child that falls on the previous or next day shifts its repeat days by −1 or +1 (Monday−1 = Sunday).
- **Estimate:** the sum of the per-challenge ranges plus `pauseSeconds × (stages − 1)`. Shown as "About X–Y min" (a range below 1 min shows "Under a minute").
- **Reminder data:**
  - Caption ≤ 120 characters.
  - The photo is stored with the existing `PhotoStore`.
  - An alarm with zero stages is valid only when it has a reminder; the editor enforces this.
- Existing alarms keep working: missing `extrasJson` means no series, no reminder and no parent.

## Rulings (taken without owner review)

- **Child ids:** `parentId * 100 + k` (k = 1…9). The main alarm keeps its id. Alarm ids stay below 21 474 836, and new main alarms skip ids that collide.
- **Navigation:** a bottom bar with Alarms | Sensor Quest | Practice replaces the app-bar icons. The editor uses section cards: When, Challenges, Series, Reminder.
- **"Skip the rest today"** skips only children of the same series whose next ring is within the next 3 hours.

## Review Focus

1. Series across midnight, in both directions (repeat days shifted correctly).
2. Editing the main alarm (time, count, direction) removes stale children and never leaves orphans, even when saving one child fails.
3. Split keeps every alarm at the same times, with no duplicates and no lost alarms.
4. Zero-stage reminder alarm: Stop shows at once, then the reminder.
5. `skipNext` survives reboot (`rescheduleAll`) and is cleared by `upsert` and `onFired`.

---

### Task 1: Native `extrasJson` and `skipNext`
**Files:** `AlarmSpec.kt`, `AlarmLifecycle.kt`, `AlarmChannel.kt`, Kotlin tests; `lib/alarm/alarm_platform.dart` (`Future<void> skipNext(int id)`), fake platform.
- `AlarmSpec.extrasJson: String = ""` is a JSON/channel pass-through like `stages`.
- `skipUntilMs: Long?` is native-only.
- `skipNext(id)`:
  - For a one-shot alarm, disable it and cancel it.
  - Otherwise, with `t1 = NextTrigger.compute(spec, now)`, store `skipUntilMs = t1` and schedule `NextTrigger.compute(spec, t1)`.
- `rescheduleAll`: when `skipUntilMs > now`, schedule after `skipUntilMs`.
- `upsert` and `onFired` clear `skipUntilMs`.
- Tests:
  - A repeating alarm skips exactly one ring.
  - A one-shot alarm is disabled.
  - The skip survives `rescheduleAll`.
  - `upsert` clears the skip.

### Task 2: Dart model — extras, reminder, series config, zero stages
**Files:** `lib/alarm/alarm.dart`, `lib/alarm/series.dart` (pure), `lib/alarm/stage_config.dart`; tests.
- `Reminder({String? photoPath, String caption})`.
- `SeriesConfig({int count, int everyMinutes, SeriesDirection direction, FollowUp followUp})`.
- `Alarm` gets `reminder`, `series`, `parentId`, all encoded in `extras`.
- `decodeStages('[]')` returns `[]`. Only missing or invalid input gives `defaultStages`.
- `List<Alarm> seriesChildren(Alarm main)` is pure. Tests:
  - after 17:00 ×5 every 5 → 17:05…17:20;
  - before 17:20 ×5 every 5 → 17:00…17:15;
  - midnight wrap in both directions with repeat days shifted;
  - children copy the label, pause and reminder;
  - `followUp.quick` gives `[StageConfig(brokenCalculator, difficulty: 2)]`;
  - ids are `parent*100+k`.

### Task 3: Estimate
**Files:** `lib/alarm/estimate.dart` (pure), shown in the stage editor and on list tiles.
- `({Duration low, Duration high}) estimateStop(List<StageConfig>, int pauseSeconds)`, using a per-challenge base in seconds (low/high) times a difficulty factor. The table lives in the file.
- `String estimateLabel(...)`.
- Tests: 4 default stages give a sensible range; a pause adds `(n−1)×pause`; zero stages give "Stops at once"; a walk with 60 steps grows the range.

### Task 4: Series in the alarm list and notifier
**Files:** `alarm_providers.dart` (save main → upsert the main alarm and its children, delete stale children; delete main → delete children; `split(mainId)`), `alarm_list_screen.dart` (children nested and indented under the main alarm with "Part of series"; tapping a child opens the main alarm), the editor's Series section (switch, count, every, direction, follow-up, preview list of times, "Split into separate alarms" with a warning).
- Tests:
  - Saving a series creates the children.
  - Changing the count from 5 to 3 removes two children.
  - Deleting the main alarm removes all of them.
  - Split clears the parent links and keeps the times.
  - The list shows children nested.

### Task 5: Reminder and the after-stop flow
**Files:**
- Editor Reminder section: take or retake the photo, caption field, "No challenges (reminder only)".
- `ring_screen.dart`: reminder card at the top. After Stop, a reminder screen with "Got it", then "Skip the rest of this series today?" for series alarms, calling `skipNext` on the siblings.
- Tests:
  - A reminder-only alarm shows Stop immediately and then the reminder screen.
  - A series alarm offers skip and calls `skipNext` for the later siblings only.

### Task 6: Navigation and docs
**Files:** `lib/app/home_screen.dart` (`NavigationBar`: Alarms, Sensor Quest, Practice), routes, README "Tools" section, checklist rows.
- Tests: the tabs switch screens; existing app-bar keys are replaced by tab keys.
