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

## Phase 1A — stages

| # | Check | Expected |
|---|---|---|
| 18 | New alarm, keep the default stages, let it ring. | Stage 1 of 4 (orientation hopscotch) shows; no Stop/Snooze buttons. |
| 19 | Complete each stage (pause between challenges: No pause). Then set the pause to 15 seconds and repeat. | No pause: the next stage starts at once. 15 s: the sound drops for 15 s ("Next stage in N s"), then full volume again. After stage 4: Stop and Snooze appear. |
| 20 | While on stage 2, run `adb shell am kill com.mrgardener.byebyesleep`. | The alarm keeps (or resumes) ringing and the ring screen reopens on stage 2, not stage 1. |
| 21 | Stay on one stage for 2 min, then 5 min. | A hint appears at 2 min; "Try a different challenge" at 5 min swaps the challenge. |
| 22 | Let an alarm ring 15 min without finishing. | "I can't finish — emergency stop" appears; a wrong sentence keeps ringing; the exact sentence stops the alarm (no snooze). |
| 23 | Orientation hopscotch: turn the phone sideways and upside down. | The screen stays upright (portrait) and the steps tick off. |
| 24 | Tilt maze at difficulty 1, 2, 3 and 4. | 1: finger drag; 2: tilt; 3: tilt reversed; 4: turning the phone turns the maze. |
| 25 | Alarm editor: reorder, change difficulty, add/remove stages, tap ▶ "Try it". | Changes are saved; "Try it" plays the challenge without sound and returns when passed. |
| 26 | Long-press the "ByeByeSleep" title. | Sensor trace recorder opens; recording shares a JSON file. |

## Phase 1B — location challenges, setup, safety

| # | Check | Expected |
|---|---|---|
| 27 | Alarm editor → "Use wake-up routine". | Stages become Lights on, Walk, Photo match, Tilt maze, Broken calculator; Photo match shows "Needs setup". |
| 28 | Set up **Lights on** with the bedroom light on, then let the alarm ring in the dark. | Black screen "Turn on the light"; switching the light on passes after 2 s. |
| 29 | Set up **Walk** by walking bed → kitchen. At ring time walk there; also try shaking the phone. | Steps count while walking (allow the "physical activity" permission); shaking barely counts. |
| 30 | Set up **Photo match** (two photos of the same view). Ring in the morning, take the photo there. | Passes from the same view even with different light; a different room shows "Not quite — N% match". |
| 31 | Set up **NFC sticker** with a tag; at ring time touch it, then try another tag. | Right tag passes; another tag says "That's a different sticker". |
| 32 | Set up **Barcode** (e.g. toothpaste). Ring and scan it, then another product. | Right code passes; another says "That's a different barcode". |
| 33 | **Charger** stage with the phone on the bedside charger. | Asks to unplug first, then passes when plugged in again. |
| 34 | Save an alarm with an unset Photo match stage. | "This alarm may not work" dialog lists the problem; "Save anyway" saves. |
| 35 | Leave such an alarm for tomorrow and wait until 21:00. | Notification "Tomorrow's alarm may not work — tap to fix". |
| 36 | With an alarm due in under 30 min, switch it off / swipe-delete / change its time. | Fingerprint/PIN prompt; cancelling keeps the alarm unchanged. Over 30 min away: no prompt. |
| 37 | Tilt maze difficulty 5. | Arrow + "On course"; when the phone turns away from the arrow the ball freezes ("Turn to the arrow!"). |
| 38 | Alarm list → game-controller icon (**Sensor Quest**). | Map lists 8 worlds; Battery Oracle shows "Play", the rest "Locked" (or "Not on this phone"). |
| 39 | **Battery Oracle**: guess within 25 of the real level, then (replay) far off. | Status bar hidden while guessing and back afterwards; a near guess shows "World complete!", a far one shows the real level, the accepted range and "Try again". |
| 40 | **Labyrinth**. | Three mazes (tilt, reversed, turning) in a row, then complete. |
| 41 | **Compass Temple**: turn on the spot holding the phone flat. | Arrow turns green near each rune direction; 2 s still lights it; 4 runes complete. |
| 42 | **Solar Garden**: start in a dim room, then go to a lamp/window. | Plant grows (lux shown) in bright light, shrinks in the dark; blooms after ~10 s of light. |
| 43 | **Ghost Hide**: follow the prompts, covering the top of the phone with a hand. | Buzz on "It is coming"; staying covered through the look counts a visit; uncovering early restarts it; 5 visits complete. |
| 44 | **Sky Tower**: start downstairs, climb one floor, wait. | "Measuring the ground floor" for 3 s, metres climb, completes ~2 s after reaching ~2.5 m. Standing still never completes. |
| 45 | **Rune Hunt**: touch 3 different NFC tags/cards (bank card works). | Same tag twice counts once; three distinct complete. |
| 46 | Close and reopen the app. | Completed worlds stay "Done". |
| 47 | Alarm list → dumbbell icon (**Practice**): run Broken calculator, then Walk. | Each challenge runs without an alarm; Walk asks for its setup first; pass shows "Passed!" and "Again". |
| 48 | While an alarm rings, tap **Emergency stop** (bottom of the ring screen) before finishing any challenge. | Checklist of 4 steps. Press a volume key (alarm volume does not change), then from Quick Settings turn Wi-Fi off, Bluetooth off, airplane mode on — any order; each ticks itself. Red "Emergency stop" appears only after all 4 and stops the alarm. |
| 49 | Photo match: set it up, then at ring time retake the photo from roughly the same spot by hand. | Reference photo shown in the corner (tap = large). Same spot passes (typically 80–95%); a different room shows "Not quite — N% match" well below 60%. |
| 50 | Alarm editor on the phone: Add challenge → pick from the bottom of the list (Charger, Barcode); add up to 8. | Picker is tall and scrolls; every challenge can be added; at 8 the button says to remove one first. No row is cut off at the right edge. |
| 51 | Home screen. | Bottom tabs Alarms / Sensor Quest / Practice; editor shows sections When, Challenges, Series, Reminder. |
| 52 | Alarm editor → Challenges. | "About X–Y min to turn off" updates when challenges, difficulty or pause change; the list shows it per alarm. |
| 53 | Series: 17:00, 5 alarms, every 5 min, "Starts at this time". Then switch to "Ends at this time". | Preview 17:00…17:20, then 16:40…17:00. The list shows the others indented under the main alarm; tapping one opens the main alarm. |
| 54 | Let a series alarm ring, finish, Stop. | Asks "Skip the rest of this series today?"; Skip → the remaining ones that day do not ring, they ring again next due day. |
| 55 | Series → "Split into separate alarms". | Warning first; then every alarm is independent (own switch, editable, deletable), same times. |
| 56 | Reminder: photo + caption "Passport", "Reminder only". Let it ring. | Ring screen shows the reminder card and Stop at once; after Stop a full-screen "Don't forget" with the photo and caption. |
| 57 | Install the watch app ([docs/watch-install.md](../watch-install.md)); Practice → *Get your heart going* → Start. | The watch opens the heart-rate screen by itself; the phone shows the live bpm, then "stay above N bpm"; walking the stairs fills the bar and passes. Leaving the challenge closes the watch screen. |
| 58 | Same with the watch off the wrist or out of range. | After about 30 s the challenge is replaced (stage) or "Sensor not answering" (Pulse Run). |
| 59 | With 3-button navigation on (Settings → System → Navigation mode): alarm editor scrolled to the end, Add challenge picker scrolled to the end, ring screen. | No button or text sits under the back / home / switch bar. |
| 60 | Practice → Compass runes, then Sensor Quest → Compass Temple. | Clear steps on screen; arrow calm (no twitching); "face east" style targets; ring fills while holding; a short wobble does not restart it. |
| 61 | Practice → Tilt maze, levels 2–4. | The ball rolls briskly and feels heavier; still never passes through walls. |
| 62 | Watch app installed: Practice → Wrist workout, then Walk with your watch. | Watch screen opens by itself showing ♥, steps; big arm swings count (small wrist moves don't); steps count on the watch even with the phone left still. |
| 63 | Alarm with "Check I'm awake: After 5 min"; let it ring, finish, Stop. | 5 min later it rings again showing "Still awake?" and one Colour words; Stop ends it; no further check after that. Reboot during the 5 min: the check still rings. |
| 64 | Add "Climb the stairs"; let it ring downstairs. | "Measuring the ground floor" 3 s, then climbing one floor and waiting there passes. |
| 65 | Retake a reminder photo, save; delete an alarm with photos. | Old photo files are removed (Settings → Apps → ByeByeSleep → storage stays small). |
| 66 | Sensor Quest → Solar Garden in bright light, lock the phone 30 s, unlock. | The plant did not grow while locked. |
| 67 | Tilt maze level 5. | "Face east: turn right 40°"; arrow steady; once facing it (±30°) "Facing east — tilt to roll" and the ball moves. |
| 68 | Add "Battery guess" (difficulty 1, then 5). | Status bar hidden; ±25% accepted at 1, ±10% at 5; old alarms that had "Charger" now show "Battery guess". |
| 69 | Settings → Smartwatch → No; then Yes + test with the watch. | "No": the picker's Watch section only says so. "Yes": install steps, live test ticks watch found / heart rate / wrist movement / steps; only passed sensors unlock watch challenges. |
| 70 | Watch challenge running; take the watch off for 30 s. | The stage switches to the fallback challenge. |
| 71 | Alarm with "Stop ringing after 10 min"; let it ring untouched. | After 10 min it stops, the ring screen closes, "Missed alarm" notification. |
| 72 | Practice → Time sense at difficulty 1 and 5. | Start, count silently, Stop: within ±3 s of 20 s passes at 1; ±1 s of 45 s at 5; misses say "Too fast/slow by X s". |
| 73 | Practice → Pulse code. | Flashes play (long ≈ 3× short); tapping them back passes; a wrong tap replays the code. |
| 74 | Practice → Colour hunt in a lit room. | Pointing at an object of the asked colour and tapping Check passes; a grey/dark scene says no clear colour. |
| 75 | iPhone (iOS 26, sideloaded): alarm in 2 min; tap Stop on the system alert. | Rings again 2 min later; tapping Challenges or opening the app shows the challenges; after finishing them no more rings. |
| 76 | Alarm with a 30 s pause; pass the first challenge, tap "Next challenge now". | The next challenge starts at once, the sound stays quiet until the 30 s are up, then full; Stop only after the last challenge. |
| 77 | Allow "Display over other apps"; set an alarm 1 min ahead and keep using the phone (another app open). | At the alarm time the challenges open by themselves, and the sound starts once they show; no notification tap needed. Also with the screen off/locked. |
