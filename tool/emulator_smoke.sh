#!/usr/bin/env bash
# Installs the debug APK, schedules an alarm 30 s ahead, turns the screen off and
# checks that the alarm rings: ring screen shown, foreground service running, alarm audio playing.
set -euo pipefail

PKG=com.mrgardener.byebyesleep
APK=build/app/outputs/flutter-apk/app-debug.apk

adb install -r -g "$APK"
adb shell appops set "$PKG" USE_FULL_SCREEN_INTENT allow || true
adb shell am start -n "$PKG/.MainActivity" --ei debug_ring_in_seconds 30
sleep 8
adb shell input keyevent KEYCODE_HOME
adb shell input keyevent KEYCODE_SLEEP

for _ in $(seq 1 45); do
  if adb shell dumpsys activity activities | grep -q "$PKG/.RingActivity"; then
    adb shell dumpsys activity services "$PKG/.alarm.AlarmService" | grep -q "isForeground=true" \
      || { echo "AlarmService is not in the foreground"; exit 1; }
    adb shell dumpsys audio | grep -q "USAGE_ALARM" \
      || { echo "No alarm audio playing"; exit 1; }
    echo "SMOKE OK"
    exit 0
  fi
  sleep 2
done

echo "RingActivity did not appear within 90 s"
adb shell dumpsys alarm | grep -A3 "$PKG" || true
adb logcat -d | grep -iE "byebyesleep|AlarmService|RingActivity|FATAL" | tail -80 || true
exit 1
