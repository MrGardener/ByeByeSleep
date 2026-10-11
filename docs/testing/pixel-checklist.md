# Pixel 10 Pro release checklist

Run on the real phone before calling a release good. Set each test alarm 2 minutes ahead
unless stated otherwise. Write the result (✅/❌ + note) next to each line.

| # | Check | Expected |
|---|---|---|
| 1 | Install the APK from the GitHub Release (allow "Install unknown apps" for your browser/files app). | App opens, shows "No alarms yet". |
| 2 | Accept the notification prompt; tap **Fix** on every item in the "Alarms may not ring" card and grant it. | Card disappears after returning to the app. |
| 3 | Set an alarm, lock the phone, screen off. | At the time the screen turns on and shows the ring screen over the lock screen; alarm sound at full volume; vibration. |
| 4 | While ringing, press volume up/down. | Volume does not change, alarm keeps ringing. |
| 5 | While ringing, use the back gesture. | Ring screen stays. |
| 6 | Tap **Stop**. | Sound and vibration stop, ring screen closes, alarm volume back to the previous level, one-shot alarm switched off in the list. |
| 7 | Set an alarm, open recents and swipe ByeByeSleep away. | Alarm still rings. |
| 8 | Connect USB, run `adb shell dumpsys deviceidle force-idle`, set an alarm. | Alarm still rings (Doze). Run `adb shell dumpsys deviceidle unforce` afterwards. |
| 9 | Set an alarm 5 minutes ahead, reboot the phone and **do not unlock it**. | Alarm rings; the notification has a **Stop** button that silences it (the ring screen needs one unlock after a reboot). |
| 10 | When an alarm rings tap **Snooze 9 min**. | Rings again 9 minutes later. |
| 11 | Snooze, then reboot during the snooze. | Still rings at the snooze time. |
| 12 | Turn on Do Not Disturb (default settings: alarms allowed). | Alarm rings. |
| 13 | Repeating alarm (e.g. every day): let it ring and Stop. | Status bar alarm icon / quick settings shows the next day's time. |
| 14 | Settings → System → Date & time: change time zone. | Alarm still rings at the same local clock time. |
| 15 | Use the phone (unlocked, another app open) when an alarm rings. | Heads-up "Alarm ringing" notification; tapping it opens the ring screen; sound plays. |
| 16 | Settings → Apps → ByeByeSleep → **Force stop**, then open the app. | Alarms still ring at their times (opening the app re-registers them). |
| 17 | Block ByeByeSleep notifications, let an alarm ring, open the app from the launcher. | The ring screen appears so the alarm can be stopped. |
