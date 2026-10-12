#!/usr/bin/env bash
# Installs the debug APK, schedules an alarm 30 s ahead, turns the screen off and checks
# that the alarm rings (ring screen, foreground service, alarm audio playing), then taps
# Stop and checks that ringing ends and the user's alarm volume is restored.
set -euo pipefail

PKG=com.mrgardener.byebyesleep
APK=build/app/outputs/flutter-apk/app-debug.apk

fail() {
  echo "FAIL: $1"
  adb logcat -d -s ByeByeSleep || true
  adb shell dumpsys audio | sed -n '/- STREAM_ALARM:/,/- STREAM_NOTIFICATION:/p' || true
  adb shell dumpsys audio | grep -iE "AudioPlaybackConfiguration|STREAM_ALARM" | head -20 || true
  adb logcat -d | grep -iE "byebyesleep|AlarmService|RingActivity|FATAL" | tail -60 || true
  exit 1
}

alarm_volume() { adb shell cmd media_session volume --stream 4 --get | grep -oE 'volume is [0-9]+' | grep -oE '[0-9]+'; }

adb install -r -g "$APK"
adb shell appops set "$PKG" USE_FULL_SCREEN_INTENT allow || true
alarm_max() { adb shell dumpsys audio | sed -n '/- STREAM_ALARM:/,/Max:/p' | grep -oE 'Max: [0-9]+' | head -1 | grep -oE '[0-9]+'; }
USER_VOLUME=$(alarm_volume)
MAX_VOLUME=$(alarm_max)
echo "alarm volume before: $USER_VOLUME (max $MAX_VOLUME)"
[ "$USER_VOLUME" != "$MAX_VOLUME" ] || fail "emulator alarm volume already at max; cannot test restore"
adb shell am start -n "$PKG/.MainActivity" --ei debug_ring_in_seconds 30
sleep 8
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_SLEEP

rang=false
for _ in $(seq 1 45); do
  if adb shell dumpsys activity activities | grep -q "$PKG/.RingActivity"; then rang=true; break; fi
  sleep 2
done
$rang || fail "RingActivity did not appear within 90 s"

adb shell dumpsys activity services "$PKG/.alarm.AlarmService" | grep -q "isForeground=true" \
  || fail "AlarmService is not in the foreground"
# Only the live player list: a started player with alarm usage.
adb shell dumpsys audio | grep -E "AudioPlaybackConfiguration" | grep "USAGE_ALARM" | grep -q "state:started" \
  || fail "No alarm audio playing"
[ "$(alarm_volume)" = "$MAX_VOLUME" ] || fail "alarm volume not raised to max while ringing (got $(alarm_volume))"
echo "RINGING OK"

# Tap the Stop button on the Flutter ring screen (found through accessibility).
sleep 3
adb shell uiautomator dump /sdcard/ui.xml >/dev/null
bounds=$(adb shell cat /sdcard/ui.xml | grep -oE '(text|content-desc)="Stop"[^>]*bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' \
  | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1)
[ -n "$bounds" ] || fail "Stop button not found on the ring screen"
read -r x1 y1 x2 y2 <<<"$(echo "$bounds" | tr -c '0-9' ' ')"
adb shell input tap $(((x1 + x2) / 2)) $(((y1 + y2) / 2))

stopped=false
for _ in $(seq 1 15); do
  if ! adb shell dumpsys activity services "$PKG/.alarm.AlarmService" | grep -q "isForeground=true"; then
    stopped=true; break
  fi
  sleep 1
done
$stopped || fail "AlarmService still ringing after Stop"
[ "$(alarm_volume)" = "$USER_VOLUME" ] || fail "alarm volume not restored (got $(alarm_volume), want $USER_VOLUME)"

echo "SMOKE OK"
